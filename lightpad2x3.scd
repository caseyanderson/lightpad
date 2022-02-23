// lightpad

///////// SETUP /////////

// ~lightpad = Group.new; // make organ group

~sources.add("lightpad");
~lightpadBus = Bus.audio(s, 1);
~lightpadAmp = Bus.control(s, 1).set(0.0);

// a = currentEnvironment;


// synth specific setup

~fft_b1 = Buffer.alloc( s, 2048, 1, completionMessage: { "fft_b1 alloced".postln } );
~fft_b2 = Buffer.alloc( s, 2048, 1, completionMessage: { "fft_b1 alloced".postln } );


// grid size sets how many synth zones there can be

~grid = 6;
~defs = Array.newClear(~grid);


// keeps track of which finger this is so synths dont get mixed up,
// also sets maximum polyphony from one lightpad

~touch = Array.newClear(~grid);


// makes x, y, and z control busses for each touch

for( 1, ~touch.size, { | i |

	a[("x"++i).asSymbol] = Bus.control(s,1).set(0.0);
	a[("y"++i).asSymbol] = Bus.control(s,1).set(0.0);
	a[("z"++i).asSymbol] = Bus.control(s,1).set(0.0);

});


~defs =[ 'cracklePV', 'input0', 'formlet', 'varsaw', 'input1', 'sinoscFB' ];


///////// SYNTHS /////////

// zone 0

SynthDef( \cracklePV, {	| attack = 0.001, release = 0.05, y = 1.95, z = 0.0, x = 0.1, trig = 0, outBus |
	var env, crackle, sig;

    env = Env.asr(attack, 0.95, release).kr(Done.freeSelf, trig);
	crackle = Crackle.ar( y.linlin( 0.0, 1.0, 0.9, 1.95), z.linlin(0.0, 0.5, 0.0, 1.0) ); //crackle just below 1..1.98 or so
	sig = IFFT( PV_BinScramble( FFT( ~fft_b1, crackle ), x.linlin(0.0, 1.0, 0.1, 0.95), 0.1, 0.5 ) ); //wipe seems to go to whatever value under 1
	Out.ar( outBus, sig * env );
}).add;


// zone 1

SynthDef( \input0, { | attack = 0.001, release = 0.05, x, y, z, trig, outBus, chn = 1 |
	var env, in, sig;

    env = Env.asr(attack, 0.95, release).kr(Done.freeSelf, trig);
	in = SoundIn.ar( chn, z.linlin(0.0, 0.5, 0.0, 1.0 ) );
	Out.ar( outBus, in * env );
}).add;


// zone 2

SynthDef(\formlet, { | attack = 0.001, release = 0.05, dens = 10, trig = 0, x, y, z, outBus |
	var env, freq, sig;

    env = Env.asr(attack, 0.95, release).kr(Done.freeSelf, trig);
    freq = Formlet.kr( Dust.kr( z.linlin(0.0, 0.5, 20, 10), 0.9), y.linlin(0.0, 1.0, 7, 200 ), 0.005, x.linlin(0.0, 1.0, 0.1, 2.0));
	sig = SinOsc.ar(freq * 200, 0.0, z.linlin(0.0, 0.5, 0.0, 1.0 ) );
	Out.ar( outBus, sig * env * 0.35 );
}).add;


// zone 3

SynthDef( \varsaw, { | attack = 0.001, release = 0.05, trig = 0, x, y, z, outBus |
	var e1 = 41.2034, e6 = 1318.510254, env, fft, sig;

    env = Env.asr(attack, 0.95, release).kr(Done.freeSelf, trig);
	sig = VarSaw.ar(y.linlin( 0.0, 1.0, e6, e1), SinOsc.kr( z, z.linlin(0.0, 0.5, 0.0, 1.0 ),0.0, z.linlin(0.0, 0.5, 0.0, 0.5 )) * 0.1);
	fft = IFFT( PV_BinScramble( FFT(~fft_b2, sig), x.linlin(0.0,1.0,1.0,0.0), 0.1, trig )) * 0.5;
	Out.ar( outBus, fft * env * 0.6 );
}).add;


// zone 4

SynthDef( \input1, { | attack = 0.001, release = 0.05, x, y, z, trig, outBus, chn = 2 |
	var env, in, sig;

    env = Env.asr(attack, 0.95, release).kr(Done.freeSelf, trig);
	in = SoundIn.ar( chn, z.linlin(0.0, 0.5, 0.0, 1.0 ) );
	Out.ar( outBus, in * env );
}).add;


// zone 5

SynthDef( \sinoscFB, { | attack = 0.001, release = 0.05, trig = 0, x, y, z, outBus |
	var env, sig;

    env = Env.asr(attack, 0.95, release).kr(Done.freeSelf, trig);
	sig = SinOscFB.ar(100 * SinOscFB.ar(y.linlin(0.0, 1.0, 1, 1000 )) + 200, x.linlin(0.0, 1.0, 0.5pi,pi), z.linlin(0.0, 0.5, 0.0, 1.0 ) ) * 0.4;
	Out.ar( outBus, sig * env  * 0.6);
}).add;


///////// OSC /////////

OSCdef(\blockOn, { | msg |
	var touchID = msg[1].asInteger;
	var column, row, grid, zone;

	// set the busses for this touchID
	a[("x"++touchID).asSymbol].set(msg[2]);
	a[("y"++touchID).asSymbol].set(msg[3]);
	a[("z"++touchID).asSymbol].set(msg[4]);


	grid = Array.iota(2, 3); // 2 x 3
	column = (msg[2]*2).snap(1,0.5);  // * 2 -> 3
	row = (msg[3]).snap(1,0.5); // * 1 -> 2

	zone = grid[row][column]; // each synth is started by a different zone (0 - 8)
	//postln("Zone is " ++ zone );
	postln("LIGHTPAD PLAYING: " ++ ~defs[zone]);
	// make the synth, put it in the touch array at position touchID
	~touch.put(touchID,
		Synth.new( ~defs[zone].asSymbol, [
			\z, a[("z"++touchID).asSymbol].asMap,
			\x, a[("x"++touchID).asSymbol].asMap,
			\y, a[("y"++touchID).asSymbol].asMap,
			\trig, 1, \outBus, ~lightpadBus.index ], ~lightpad );
	);

}, 	'/block/lightpad/0/on');


OSCdef(\blockPos, { | msg |
	var touchID = msg[1].asInteger;

	// set the busses for this touchID
	a[("x"++touchID).asSymbol].set(msg[2]);
	a[("y"++touchID).asSymbol].set(msg[3]);
	a[("z"++touchID).asSymbol].set(msg[4]);

	//postln("x is "  ++ msg[2] ++ " y is " ++ msg[3] );
	// update parameters for synth as position changes
	~touch[touchID].set(
		\z, a[("z"++touchID).asSymbol].asMap,
		\x, a[("x"++touchID).asSymbol].asMap,
		\y, a[("y"++touchID).asSymbol].asMap,
	\trig, 1 );

}, '/block/lightpad/0/position');


OSCdef(\blockOff, { | msg |
	var touchID = msg[1];

	// kill active synth on noteoff
	~touch[touchID.asInteger].set(\trig, 0);

}, '/block/lightpad/0/off');

