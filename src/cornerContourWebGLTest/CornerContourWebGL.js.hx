package cornerContourWebGLTest;

import cornerContour.io.Float32Array;
import cornerContour.io.ColorTriangles2D;
import cornerContour.io.IteratorRange;
import cornerContour.io.Array2DTriangles;
// contour code
import cornerContour.Sketcher;
import cornerContour.Pen2D;
import cornerContour.StyleSketch;
import cornerContour.StyleEndLine;
// SVG path parser
import justPath.*;
import justPath.transform.ScaleContext;
import justPath.transform.ScaleTranslateContext;
import justPath.transform.TranslationContext;

import js.html.webgl.RenderingContext;
import js.html.CanvasRenderingContext2D;

// html stuff
import cornerContour.web.Sheet;
import cornerContour.web.DivertTrace;

import htmlHelper.tools.AnimateTimer;
import cornerContour.web.Renderer;

// webgl gl stuff
import cornerContour.web.ShaderColor2D;
import cornerContour.web.HelpGL;
import cornerContour.web.BufferGL;
import cornerContour.web.GL;

// js webgl 
import js.html.webgl.Buffer;
import js.html.webgl.RenderingContext;
import js.html.webgl.Program;
import js.html.webgl.Texture;

// Opening and parsing font
// use hxTrueType on nanjizal.
import truetype.TTFGlyphUtils;
import format.ttf.Data;
import haxe.io.BytesInput;

function main(){
    new CornerContourWebGL();
}

class CornerContourWebGL {
    // cornerContour specific code
    var sketcher:       Sketcher;
    var pen2D:          Pen2D;
    // WebGL/Html specific code
    public var gl:               RenderingContext;
        // general inputs
    final vertexPosition         = 'vertexPosition';
    final vertexColor            = 'vertexColor';
    // general
    public var width:            Int;
    public var height:           Int;
    public var mainSheet:        Sheet;
    var divertTrace:             DivertTrace;
    var renderer:                Renderer;
    
    public function new(){
        divertTrace = new DivertTrace();
        trace('Contour Test');
        width = 1024;
        height = 768;
        creategl();
        // use Pen to draw to Array
        initContours();
        renderer = { gl: gl, pen: pen2D, width: width, height: height };
        draw();
        renderer.rearrangeData();
        renderer.setup();
        setAnimate();
    }
    inline
    function creategl( ){
        mainSheet = new Sheet();
        mainSheet.create( width, height, true );
        gl = mainSheet.gl;
    }
    
    public function parseFont(){
        var bytes                        = haxe.Resource.getBytes( "font" );
        var bytesInput                   = new BytesInput(bytes);
        var ttfReader: format.ttf.Reader = new format.ttf.Reader( bytesInput );
        var ttf:     TTF                 = ttfReader.read();
        var fontUtils                    = new TTFGlyphUtils( ttf );
        var str = "The quick brown fox jumps over the lazy dog.";
        //'But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?';
        var haxeLetters = str.split('');
        var space = 0.;
        var y2 = 0.;
        var displayScale = 0.5;
        for( letter in haxeLetters ){
            // trace( 'letter ' + letter );
            space += displayGlyph( letter.charCodeAt( 0 ) - 28, fontUtils, displayScale, space, y2 );
            if( space > 500 && letter == ' ' ){
                space = 0;
                y2 += 80*displayScale;
            }
        }
    }
    public function displayGlyph( index:Int, utils:TTFGlyphUtils, displayScale = 4., space: Float = 0., y2: Float = 0 ): Float {
        var glyph:GlyphSimple = utils.getGlyphSimple(index);
        if (glyph == null) return 20*displayScale;
        var glyphHeader:GlyphHeader = utils.getGlyphHeader(index);
        var contours = utils.getGlyphContours(index);
        var scale: Float = (64 / utils.headdata.unitsPerEm) * displayScale;
        var x = 172*3*scale + space;
        var y =  100 + y2;
        var dy = utils.headdata.yMax;
        var maxX = 0.;
        var s = Std.int( pen2D.pos );
        for( contour in contours ) {
            var newX = drawContour( contour, x, y, scale ) - x + displayScale*5;
            if( maxX < newX ) maxX = newX;
        }
        allRange.push( s...Std.int( pen2D.pos - 1 ) );
        return maxX;
    }
    public function drawContour( contour: Array<ContourPoint>
                            , x: Float, y: Float, scale: Float ): Float {
        var offCurvePoint: ContourPoint = null;
        var ax: Float;
        var ay: Float;
        var bx: Float;
        var by: Float;
        var maxX: Float = 0.;
        for (i in 0...contour.length) {
            var point = contour[ i ];
            if (i == 0) {
                ax = scale*point.x + x;
                ay = -scale*point.y + y;
                if( maxX < ax ) maxX = ax;
                sketcher.moveTo( ax, ay );
            } else {
                var prevPoint = contour[ i - 1 ];
                if( point.onCurve ) {
                    if( prevPoint.onCurve ) {
                        ax = scale*point.x + x;
                        ay = -scale*point.y + y;
                        if( maxX < ax ) maxX = ax;
                        sketcher.lineTo( ax, ay );
                    } else {
                        ax = scale*offCurvePoint.x + x;
                        ay = -scale*offCurvePoint.y + y;
                        if( maxX < ax ) maxX = ax;
                        bx = scale*point.x + x;
                        by = -scale*point.y + y;
                        if( maxX < bx ) maxX = bx;
                        sketcher.quadTo( ax, ay, bx, by );
                    }
                } else {
                    offCurvePoint = contour[ i ];
                }
            }
        }
        return maxX;
    }
    public
    function initContours(){
        pen2D = new Pen2D( 0xFF0000FF );
        pen2D.currentColor = 0xffFFFFFF;
        sketcher = new Sketcher( pen2D, StyleSketch.Fine, StyleEndLine.no );
        sketcher.width = 1;
    }
    public function draw(){
        parseFont();
        renderer.rearrangeData(); // destroy data and rebuild
        renderer.updateData(); // update
    }

    var allRange = new Array<IteratorRange>();
    var theta = 0.;
    inline
    function render(){
        for( i in allRange ){
            renderer.arrData.translateRange( i, 0, 0.0004*Math.sin( theta ) );
            renderer.arrData.blendBetweenColorRange( 0xFFff0000, 0xFF0fff00, i, Math.cos( theta ));
            theta += 30*Math.PI/180;
        }
        theta += 1*Math.PI/180;
        renderer.updateData();
        clearAll( gl, width, height, 0., 0., 0., 1. );
        renderer.drawData( allRange[0].start...allRange[allRange.length-1].max );
        
    }
    inline
    function setAnimate(){
        AnimateTimer.create();
        AnimateTimer.onFrame = function( v: Int ) render();
    }
}