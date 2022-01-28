/*
Mother Host
*/

(
/* Receive Incoming OSC messages on port 4001
Messages sent from mother.scd, e.g.,
~motherHost = NetAddr("127.0.0.1", 4001);
~motherHost.sendMsg("/patchLoaded",1);
*/

/*
# patchLoaded
~motherHost.sendMsg("/patchLoaded",1);
*/
OSCdef( \OrganellePatchLoaded,
	{
		arg msg, time, addr, recvPort;
		msg.postln;
		~readKnobs.defer;
		~sendKnobs;
	},
	"/patchLoaded",
	recvPort:4001
);

/*
# led
~motherHost.sendMsg("/led", i.asInteger);
what are the colors?? check a patch or trial/error
0: off
1: green
*/
OSCdef( \OrganelleLed,
	{
		arg msg, time, addr, recvPort;
		msg.postln;
	},
	"/led",
	recvPort:4001
);

/*
# VU Meter
~motherHost.sendMsg("/oled/vumeter", peakInL,peakInR,peakOutL,peakOutR, 0);
todo: figure out how to set the peaks based on the single value
*/
OSCdef( \OrganelleVuMeter,
	{
		arg msg, time, addr, recvPort;
		msg.postln;
	},
	"/oled/vumeter",
	recvPort:4001
);

/*
# Set Screen
~motherHost.sendMsg("/oled/setscreen",3);
todo: what does this do?
*/
OSCdef( \OrganelleSetScreen,
	{
		arg msg, time, addr, recvPort;
		msg.postln;
	},
	"/oled/setscreen",
	recvPort:4001
);

/*
# Oled Line
~motherHost.sendMsg(format("/oled/line/%",line), str);
todo: will this receive all /oled/line/1-5? do I need a wild card?
*/
OSCdef( \OrganelleOledLine1,
	{
		arg msg, time, addr, recvPort;
		{~oledLine1.string_(msg[1])}.defer;
	},
	"/oled/line/1",
	recvPort:4001
);
OSCdef( \OrganelleOledLine2,
	{
		arg msg, time, addr, recvPort;
		{~oledLine2.string_(msg[1])}.defer;
	},
	"/oled/line/2",
	recvPort:4001
);
OSCdef( \OrganelleOledLine3,
	{
		arg msg, time, addr, recvPort;
		{~oledLine3.string_(msg[1])}.defer;
	},
	"/oled/line/3",
	recvPort:4001
);
OSCdef( \OrganelleOledLine4,
	{
		arg msg, time, addr, recvPort;
		{~oledLine4.string_(msg[1])}.defer;
	},
	"/oled/line/4",
	recvPort:4001
);
OSCdef( \OrganelleOledLine5,
	{
		arg msg, time, addr, recvPort;
		{~oledLine5.string_(msg[1])}.defer;
	},
	"/oled/line/5",
	recvPort:4001
);

/* Send OSC messages to mother on port 4000
*/
~mother = NetAddr("127.0.0.1", 4000);

/*
# Send Knobs
/knobs
/knobs iiiiii 604 342 451 64 666 1023
knobs 1-4 = pots, 5 = volume , 6 = expr pedal
~sendKnobs = {
	~mother.sendMsg("/knobs",
		(~knob1.value * 1024).round(),
		(~knob2.value * 1024).round(),
		(~knob3.value * 1024).round(),
		(~knob4.value * 1024).round(),
		(~knobVol.value * 1024).round(),
		0
	)
};
*/

/*
todo

# Send OSC on port 4000

/key
/key ii 10 100
aux key = 0, C = 1 (and midi = 60)


/enc
/enc i 1
enc = 1 = clockwise, 0 anti

/encbut
/encbut i 1

/fs
/fs  i 1

not implement yet
    /footSwitchPolarity
    /quit
    /midich

*/

~readKnobs = {
	f = File("/tmp/patch/knobs.txt","r");
	~knobsTxt = f.readAllString;
	~knobsTxt = ~knobsTxt[0..~knobsTxt.size-2];
	~knobsTxt = ~knobsTxt.split($ );
	~knob1.valueAction = ~knobsTxt[0];
	~knob2.valueAction = ~knobsTxt[1];
	~knob3.valueAction = ~knobsTxt[2];
	~knob4.valueAction = ~knobsTxt[3];
	f.close;
//x = FileReader.read("/tmp/patch/knobs.txt").postcs;

};

~writeKnobs = {
	f = File("/tmp/patch/knobs.txt","w");
	f.write(
		format("% % % %;",
			~knob1.value.round(1e-6),
			~knob2.value.round(1e-6),
			~knob3.value.round(1e-6),
			~knob4.value.round(1e-6)
		)
	);
	f.close;
};

~sendKnobs = {
	//~mother.sendMsg("/knobs", (~knob1.value * 1024).round);
//	[(~knob1.value * 1024).round, ~knob2.value, ~knob3.value, ~knob4.value, ~knobVol.value].postln;
	~mother.sendMsg("/knobs",
		(~knob1.value * 1024).round.asInteger,
		(~knob2.value * 1024).round.asInteger,
		(~knob3.value * 1024).round.asInteger,
		(~knob4.value * 1024).round.asInteger,
		(~knobVol.value * 1024).round().asInteger,
		0
	)
};

)

(
~motherPatch = PathName(thisProcess.nowExecutingPath).parentPath ++ "mother.scd";


~startPatch = {
	FileDialog({ |path|
		~patchPath = PathName(path);
		~patchPath.files.do({
			arg item;
			if (item.fileName == "main.scd",
				{
					~patchName = item.folderName;
					~patchNameView.string_(~patchName);
					p = Pipe.new(format("ln -s \"%\" /tmp/patch", ~patchPath.fullPath),"r");
					p.close;
					~motherPatch.load;
				}
			);
		});
	},
	stripResult: true,
	fileMode: 2);
};

~stopPatch = {
	p = Pipe.new("rm /tmp/patch","r");
	p.close;
	s.freeAll;
	s.quit;
	~patchPath = Nil;
	~patchName = Nil;
	~patchNameView.string_("");
	~oledLine1.string_("");
	~oledLine2.string_("");
	~oledLine3.string_("");
	~oledLine4.string_("");
	~oledLine5.string_("");
	//s.freeAll;0,0,0

};


Window.closeAll;

w = Window.new("Mother Host", Rect(800,100,615,350)).layout_(
	VLayout(

		HLayout(
			// Convert to toolbar??
			Button.new(w,Rect(0,0,50,30))
			.states_([["start"],["stop"]])
			.maxWidth_(100)
			.maxHeight_(30)
			.action_({ arg butt;
				if(butt.value==0,
					{
						//"stop".postln;
						~writeKnobs.value;
						~stopPatch.value;

					},
					{
						//"start".postln;
						~stopPatch.value;
						~startPatch.value;

						//s.sync;
						//~readKnobs;
					}
				)
			}),
			~patchNameView = StaticText().align_(\left)
		),

		HLayout(

			VLayout(
				StaticText().string_("1").align_(\right).maxHeight_(30),
				~knob1 = Knob().action_(~sendKnobs).mode_(\vert)
			),
			VLayout(
				StaticText().string_("2").align_(\right).maxHeight_(30),
				~knob2 = Knob().action_(~sendKnobs).mode_(\vert)
			),
			VLayout(
				StaticText().string_("3").align_(\right).maxHeight_(30),
				~knob3 = Knob().action_(~sendKnobs).mode_(\vert)
			),
			VLayout(
				StaticText().string_("4").align_(\right).maxHeight_(30),
				~knob4 = Knob().action_(~sendKnobs).mode_(\vert)
			),
			VLayout(

				// Oled Text
				~oledLine0 = StaticText().string_("I----------||----------I")
				.stringColor_(Color.white).background_(Color.black).align_(\left),
				~oledLine1 = StaticText()
				.stringColor_(Color.white).background_(Color.black).align_(\left),
				~oledLine2 = StaticText()
				.stringColor_(Color.white).background_(Color.black).align_(\left),
				~oledLine3 = StaticText()
				.stringColor_(Color.white).background_(Color.black).align_(\left),
				~oledLine4 = StaticText()
				.stringColor_(Color.white).background_(Color.black).align_(\left),
				~oledLine5 = StaticText()
				.stringColor_(Color.white).background_(Color.black).align_(\left)

			),
			VLayout(
				StaticText().string_("Vol").align_(\left).maxHeight_(30),
				~knobVol = Knob().action_(~sendKnobs).mode_(\vert)
			)

//			StaticText().string_("Vol").align_(\left)
			/*StaticText.new().string_("1").align_(\right),
			StaticText.new(w,Rect(95,30,50,40)).string_("2").align_(\right),
			StaticText.new(w,Rect(160,30,50,40)).string_("3").align_(\right),
			StaticText.new(w,Rect(225,30,50,40)).string_("4").align_(\right),
			StaticText.new(w,Rect(510,30,50,40)).string_("Vol").align_(\left)
			*/
		),
		HLayout(

			VLayout(
				Button(),
				Button()
			),
			VLayout(
				HLayout(
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button()
				),
				HLayout(
					Button()
					.states_([["1"]])
					.mouseDownAction_({~mother.sendMsg("/key",1,100)})
					.action_({ arg butt, mod;
						~mother.sendMsg("/key",1,0);
					}),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button(),
					Button()

				)
			)
		)
/*
		HLayout(
			// Knob Labels
			~knob1 = Knob().action_(~sendKnobs).mode_(\vert),
			~knob2 = Knob().action_(~sendKnobs).mode_(\vert),
			~knob3 = Knob().action_(~sendKnobs).mode_(\vert),
			~knob4 = Knob().action_(~sendKnobs).mode_(\vert),
			StaticText(),
			~knobVol = Knob().action_(~sendKnobs).mode_(\vert)
			/*~knob1 = Knob.new(w,Rect(30,60,50,50))
			.action_(~sendKnobs)
			.mode_(\vert);
			~knob2 = Knob.new(w,Rect(95,60,50,50))
			.action_(~sendKnobs)
			.mode_(\vert);
			~knob3 = Knob.new(w,Rect(160,60,50,50))
			.action_(~sendKnobs)
			.mode_(\vert);
			~knob4 = Knob.new(w,Rect(225,60,50,50))
			.action_(~sendKnobs)
			.mode_(\vert);
			~knobVol = Knob.new(w,Rect(530,60,50,50))
			.action_(~sendKnobs)
			.mode_(\vert);
			*/
		),
*/

	)
);
w.view.background_(Color.new(1,1,1));
w.front;
)