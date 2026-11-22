#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif
#include "processing.h"
#include "libraries/io.h"
#include "libraries/serial.h"
#include "libraries/net.h"
#include "libraries/osc.h"
#include "libraries/video.h"
#include "libraries/arduino.h"
#include "libraries/midi.h"
#include "libraries/geomerative.h"
#include "libraries/xml.h"
#include "libraries/minim.h"

typedef PdeRecorder Recorder;
#define Recorder_ctor PdeRecorder_ctor

extern bool record;
extern GifMaker gifExport;


#line 3 "sketch.pde"
bool record = false;
#line 4 "sketch.pde"
GifMaker gifExport;
#line 7 "sketch.pde"
void setup(void){ 
#line 8 "sketch.pde"
size_converted(720, 576);
#line 10 "sketch.pde"
PFont font = loadFont( "UniversLTStd-Bold-16.vlw");
#line 11 "sketch.pde"
textFont( font);
#line 13 "sketch.pde"
if( record){ 
#line 14 "sketch.pde"
gifExport = GifMaker_ctor( NULL, "export.gif");
#line 15 "sketch.pde"
gifExport.setRepeat( 0);
#line 16 "sketch.pde"
}
#line 17 "sketch.pde"
} 
#line 20 "sketch.pde"
void draw(void){ 
#line 21 "sketch.pde"
background( 0);
#line 23 "sketch.pde"
int cnt = 0;
#line 25 "sketch.pde"
for( int i = 0;
i < height;
i ++ ){ 
#line 26 "sketch.pde"
int h = i + ( int)(( noise( sin(( i / 19.0 + 0.0f) * TAU), cos( cnt ++ / 199.0 * TAU)) - 0.5f) * 1000.0);
#line 27 "sketch.pde"
double x = 
#line 28 "sketch.pde"
( sin( frameCount / 60.0 + h + ( h * 0.0001f * noise( frameCount / 1600.1 + h / 575.494, h / 1000.1234 + 0.0f + frameCount / 600.0)) * TAU) + 1.0) / 2.0 * width;
#line 29 "sketch.pde"
float l = pow( noise( cnt / 1000.0123, ( float) x / 999.0, cos( frameCount / 1000.0 + ( cnt / 10000.1) * TAU) * 10.0), 4.0) * 100.0;
#line 33 "sketch.pde"
stroke( 255, 127);
#line 34 "sketch.pde"
pushMatrix();
#line 35 "sketch.pde"
translate(( float) x / 2.0 + width / 4, h / 2.0 + height / 3.0);
#line 36 "sketch.pde"
rotate( atan2( height / 2 - h, width / 2 - ( float) x));
#line 37 "sketch.pde"
line(( float) l * - 1, 2, ( float) l, 0);
#line 38 "sketch.pde"
popMatrix();
#line 39 "sketch.pde"
} 
#line 43 "sketch.pde"
fill( 255, 127);
#line 44 "sketch.pde"
text( "kof 26", width - 120, height - 18);
#line 47 "sketch.pde"
if( record){ 
#line 48 "sketch.pde"
gifExport.setDelay( 1);
#line 49 "sketch.pde"
gifExport.addFrame();
#line 51 "sketch.pde"
}
#line 52 "sketch.pde"
} 
#line 56 "sketch.pde"
void keyPressed_event(void){ 
#line 57 "sketch.pde"
gifExport.finish();
#line 58 "sketch.pde"
println( "gif saved");
#line 59 "sketch.pde"
}

int main(void) {
    setup();
    if (_windowInit == 0) size3(640, 480, "Processing Ray");
    while (!WindowShouldClose() && !_exitRequested) {
        beginDraw();
        if (_loopRunning || _redrawPending) {
            _redrawPending = false;
            draw();
        }
        endDraw();
    }
    destroyProcessing();
    CloseWindow();
    return 0;
}
