// initialize parameters and screen
~stretch = 50;
~hpf = 20;
~dry = 0.5;
~wet = 0.5;

~oled.screen(1,format("Stretch: %x",~stretch));
~oled.screen(2,format("Cutoff: % Hz",~hpf.asInteger));
~oled.screen(3,format("Dry: %",~dry.round(1e-2)));
~oled.screen(4,format("Wet: %",~wet.round(1e-2)));
~oled.screen(5,"Stretch.sc");

// create knob callback
~knobfunc = {
	arg func, msg, knob, value;
	switch (knob,
		0, {
			~stretch = value.linlin(0,1,10,100).asInteger;
			~oled.screen(1,format("Stretch: %",~stretch.asInteger));
			~stretchL.set(\stretch, ~stretch);
			~stretchR.set(\stretch, ~stretch);
		},
		1, {
			~hpf = value.linlin(0,1,20,2000).asInteger;
			~oled.screen(2,format("Cutoff: % Hz",~hpf.asInteger));
			~stretchL.set(\hpf, ~hpf);
			~stretchR.set(\hpf, ~hpf);
		},
		2, {
			~dry = value;
			~oled.screen(3,format("Dry: %",~dry.round(1e-2)));
			~dryLR.set(\amp, ~dry);
		},
		3, {
			~wet = value;
			~oled.screen(4,format("Wet: %",~wet.round(1e-2)));
			~stretchL.set(\amp, ~wet);
			~stretchR.set(\amp, ~wet);
		}
	);
};

// register knob callback
~knobs.addDependant(~knobfunc);

// create aux callback
~auxfunc = {
	arg func, msg, key, vel;
	if (key,
		{
			~recL.set(\preLevel, 1);
			~recR.set(\preLevel, 1);
			~led.value(3);
			~oled.screen(5,"Stretch.sc ...");
		},
		{
			~recL.set(\preLevel, 0);
			~recR.set(\preLevel, 0);
			~led.value(0);
			~oled.screen(5,"Stretch.sc");
		}
	);
};

// register aux callback
~aux.addDependant(~auxfunc);


// setup buses and groups
//~effectsBus = Bus.audio(s, 2);
//~srcGroup = Group.new;
//~effectsGroup = Group.after(~srcGroup);

~recBufL = Buffer.alloc(s, 44100 * 4.0, 1);
~recBufR = Buffer.alloc(s, 44100 * 4.0, 1);
~envBuf = Buffer.alloc(s, s.sampleRate, 1);
~envSignal = Signal.newClear(s.sampleRate).waveFill({|x| (1 - x.pow(2)).pow(1.25)}, -1.0, 1.0);
~envBuf.loadCollection(~envSignal);

// SynthDefs
SynthDef(\paulstretchMono, { |out = 0, bufnum, envBufnum, pan = 0.5, stretch = 50, window = 0.05, amp = 1, hpf = 20|
	// Paulstretch for SuperCollider
	// Based on the Paul's Extreme Sound Stretch algorithm by Nasca Octavian PAUL
	// https://github.com/paulnasca/paulstretch_python/blob/master/paulstretch_steps.png
	//
	// By Jean-Philippe Drecourt
	// http://drecourt.com
	// April 2020
	//
	// Arguments:
	// out: output bus (stereo output)
	// bufnum: the sound buffer. Must be Mono. (Use 2 instances with Buffer.readChannel for stereo)
	// envBufnum: The grain envelope buffer created as follows:
	//// envBuf = Buffer.alloc(s, s.sampleRate, 1);
	//// envSignal = Signal.newClear(s.sampleRate).waveFill({|x| (1 - x.pow(2)).pow(1.25)}, -1.0, 1.0);
	//// envBuf.loadCollection(envSignal);
	// pan: Equal power panning, useful for stereo use.
	// stretch: stretch factor (modulatable)
	// window: the suggested grain size, will be resized to closest fft window size
	// amp: amplification
	var trigPeriod, sig, chain, trig, pos, fftSize;
	// Calculating fft buffer size according to suggested window size
	fftSize = 2**floor(log2(window*SampleRate.ir));
	// Grain parameters
	// The grain is the exact length of the FFT window
	trigPeriod = fftSize/SampleRate.ir;
	trig = Impulse.ar(1/trigPeriod);
	pos = Demand.ar(trig, 0, demandUGens: Dseries(0, trigPeriod/stretch));
	// Extraction of 2 consecutive grains
	// Both grains need to be treated together for superposition afterwards
	sig = [GrainBuf.ar(1, trig, trigPeriod, bufnum, 1, pos, envbufnum: envBufnum),
		GrainBuf.ar(1, trig, trigPeriod, bufnum, 1, pos + (trigPeriod/(2*stretch)), envbufnum: envBufnum)]*amp;
	// FFT magic
	sig = sig.collect({ |item, i|
		chain = FFT(LocalBuf(fftSize), item, hop: 1.0, wintype: -1);
		// PV_Diffuser is only active if its trigger is 1
		// And it needs to be reset for each grain to get the smooth envelope
		chain = PV_Diffuser(chain, 1 - trig);
		item = IFFT(chain, wintype: -1);
	});
	// Reapply the grain envelope because the FFT phase randomization removes it
	sig = sig*PlayBuf.ar(1, envBufnum, 1/(trigPeriod), loop:1);
	// Delay second grain by half a grain length for superposition
	sig[1] = DelayC.ar(sig[1], trigPeriod/2, trigPeriod/2);
	// Panned output
	Out.ar(out, Pan2.ar(HPF.ar(Mix.new(sig), freq: hpf), pan));
}).add;

SynthDef(\recBufDef, {
	arg channel = 0, bufnum = 0, preLevel = 0, loop = 1, run = 1;
	RecordBuf.ar(
		inputArray: SoundIn.ar(channel),
		bufnum: bufnum,
		preLevel: preLevel,
		loop: loop,
		run: run
	);
}).add;

SynthDef.new(\dryDef, {
	arg amp = 1;
	var in;
	in = SoundIn.ar([0, 1]) * amp;
	Out.ar(~outL, in);
}).add;

// Make sure the SynthDefs are ready before we use them
s.sync;

// Setup the input and effects

~dryLR = Synth(\dryDef, [amp: ~dry]);
//~dryLR = Synth(\dryDef, [amp: ~dry]);
//~dryLR.set(\amp, 0.5);

~recL = Synth(\recBufDef,[channel: 0, bufnum: ~recBufL]);
~recR = Synth(\recBufDef,[channel: 1, bufnum: ~recBufR]);
~stretchL = Synth(\paulstretchMono,
	[
		out: ~outL,
		bufnum: ~recBufL.bufnum,
		envBufnum: ~envBuf.bufnum,
		stretch: ~stretch,
		amp: ~wet,
		hpf: ~hpf
	]
);
~stretchR = Synth(\paulstretchMono,
	[
		out: ~outR,
		bufnum: ~recBufR.bufnum,
		envBufnum: ~envBuf.bufnum,
		stretch: ~stretch,
		amp: ~wet
		hpf: ~hpf
	]
);