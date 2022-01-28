// initialize parameters and screen
~damp = 0.85;
~mix = 0.08;
~room = 0.999;

~oled.screen(1,format("Damp: %",~damp.round(1e-4)));
~oled.screen(2,format("Mix: %",~mix.round(1e-4)));
~oled.screen(3,format("Room: %",~room.round(1e-4)));
~oled.screen(5,~mainVolume);

// create knob callback
~knobfunc = {
	arg func, msg, knob, value;
	switch (knob,
		0, {
			~damp = value;
			~oled.screen(1,format("Damp: %",~damp.round(1e-2)));
			~reverb.set(\damp, ~damp);
		},
		1, {
			~mix = value;
			~oled.screen(2,format("Mix: %",~mix.round(1e-2)));
			~reverb.set(\mix, ~mix);
		},
		2, {
			~room = value;
			~oled.screen(3,format("Room: %",~room.round(1e-2)));
			~reverb.set(\rev, ~room);
		}
	);
};

// register knob callback
~knobs.addDependant(~knobfunc);

// setup buses and groups
~effectsBus = Bus.audio(s, 2);
~srcGroup = Group.new;
~effectsGroup = Group.after(~srcGroup);

// SynthDefs
SynthDef.new(\reverbDef, {
	arg in=0, mix=0.08, room=0.999, damp=0.85, out=0;
	var sig;
	sig = In.ar(~effectsBus, 2);
	sig = FreeVerb2.ar(
		sig[0], sig[1],
		mix: mix.varlag(2),
		room: room,
		damp: damp
	);
	Out.ar(~outL, sig);
}).add;

SynthDef.new(\inLRDef, {
	var inSig,inScale;
	inScale = 0.1
	inSig = SoundIn.ar([0,1]) * inScale;
	Out.ar(~effectsBus, inSig);
}).add;

// Make sure the SynthDefs are ready before we use them
s.sync;

// Setup the input and effects
~inLR = Synth(\inLRDef, target:~srcGroup);
~reverb = Synth(\reverbDef, target:~effectsGroup);