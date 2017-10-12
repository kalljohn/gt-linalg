## /* -*- javascript -*-

<%! draggable=True %>

<%inherit file="base.mako"/>

<%block name="title">Composing Transformations</%block>

<%block name="extra_script">
    <script type="application/glsl" id="vertex-xyz">
    // Enable STPQ mapping
    #define POSITION_STPQ
    void getPosition(inout vec4 xyzw, inout vec4 stpq) {
        // Store XYZ per vertex in STPQ
        stpq = xyzw;
    }
    </script>

    <script type="application/glsl" id="fragment-clipping">
    // Enable STPQ mapping
    #define POSITION_STPQ
    uniform float range;

    vec4 getColor(vec4 rgba, inout vec4 stpq) {
        stpq = abs(stpq);

        // Discard pixels outside of clip box
        if(stpq.x > range || stpq.y > range || stpq.z > range)
            discard;

        return rgba;
    }
    </script>
</%block>

## */

function decodeQS() {
    var decode, match, pl, query, search;
    pl = /\+/g;
    search = /([^&=]+)=?([^&]*)/g;
    decode = function(s) {
        return decodeURIComponent(s.replace(pl, " "));
    };
    query = window.location.search.substring(1);
    var urlParams = {};
    while (match = search.exec(query)) {
        urlParams[decode(match[1])] = decode(match[2]);
    }
    return urlParams;
}
var paramsQS = decodeQS();
var range = paramsQS.range || 10;

var matrix1 = [1,0,0,1];
if(paramsQS.mat1)
    matrix1 = paramsQS.mat1.split(',').map(parseFloat)
var matrix2 = [1,0,0,1];
if(paramsQS.mat2)
    matrix2 = paramsQS.mat2.split(',').map(parseFloat)
var matrix = [
    matrix2[0]*matrix1[0] + matrix2[1]*matrix1[2],
    matrix2[0]*matrix1[1] + matrix2[1]*matrix1[3],
    matrix2[2]*matrix1[0] + matrix2[3]*matrix1[2],
    matrix2[2]*matrix1[1] + matrix2[3]*matrix1[3]
];
var matrices = [matrix1, matrix2];


var setMat = function(mat, a, b, c, d) {
    mat[0] = a; mat[1] = b; mat[2] = c; mat[3] = d;
}

var updateMatrix = function() {
    setMat(matrix, 1, 0, 0, 1);
    for(var i = 0; i < numTransforms; ++i) {
        var mult = paramses[i].matrix;
        var a = mult[0]*matrix[0] + mult[1]*matrix[2];
        var b = mult[0]*matrix[1] + mult[1]*matrix[3];
        var c = mult[2]*matrix[0] + mult[3]*matrix[2];
        var d = mult[2]*matrix[1] + mult[3]*matrix[3];
        setMat(matrix, a, b, c, d);
    }
    updateMatrices();
}

var doScale = function(params) {
    params.rotate = 0.0;
    params.xshear = 0.0;
    params.yshear = 0.0;
    setMat(params.matrix, params.xscale, 0, 0, params.yscale);
    updateMatrix();
};
var doXShear = function(params) {
    params.xscale = 1.0;
    params.yscale = 1.0;
    params.rotate = 0.0;
    params.yshear = 0.0;
    setMat(params.matrix, 1,params.xshear,0,1);
    updateMatrix();
};
var doYShear = function(params) {
    params.xscale = 1.0;
    params.yscale = 1.0;
    params.rotate = 0.0;
    params.xshear = 0.0;
    setMat(params.matrix, 1,0,params.yshear,1);
    updateMatrix();
};
var doRotate = function(params) {
    params.xscale = 1.0;
    params.yscale = 1.0;
    params.xshear = 0.0;
    params.yshear = 0.0;
    var r = params.rotate * Math.PI / 180;
    var c = Math.cos(r);
    var s = Math.sin(r);
    setMat(params.matrix, c, -s, s, c);
    updateMatrix();
};

var Params = function(mat, inverseName) {
    this.xscale = 1.0;
    this.yscale = 1.0;
    this.rotate = 0.0;
    this.xshear = 0.0;
    this.yshear = 0.0;
    this.matrix = mat;
    this[inverseName] = function() {
        var det = this.other[0] * this.other[3] - this.other[1] * this.other[2];
        if(Math.abs(det) < .00001) {
            window.alert("Matrix is not invertible!")
            return;
        }
        this.xscale = 1.0;
        this.yscale = 1.0;
        this.rotate = 0.0;
        this.xshear = 0.0;
        this.yshear = 0.0;
        setMat(this.matrix,
                this.other[3]/det, -this.other[1]/det,
               -this.other[2]/det,  this.other[0]/det);
        updateMatrix();
    }
    this['show grid'] = true;
};

var numTransforms = 2;
var paramses = [];
var gui = new dat.GUI();
var folderNames = ['U', 'T'];
var inverseNames = ['T inverse', 'U inverse']
var folders = [];
for(var i = 0; i < numTransforms; ++i) {
    (function(params) {
        var folder = gui.addFolder(folderNames[i]);
        folder.open();
        folder.add(params, 'xscale', -2, 2).step(0.05).onChange(function() {
            doScale(params);
        }).listen();
        folder.add(params, 'yscale', -2, 2).step(0.05).onChange(function() {
            doScale(params);
        }).listen();
        folder.add(params, 'rotate', -180, 180).step(5)
            .onChange(function() {
                doRotate(params);
            }).listen();
        folder.add(params, 'xshear', -2, 2).step(0.05).onChange(function() {
            doXShear(params);
        }).listen();
        folder.add(params, 'yshear', -2, 2).step(0.05).onChange(function() {
            doYShear(params);
        }).listen();
        paramses.push(params);
        folder.add(params, inverseNames[i]);
        folders.push(folder);
    })(new Params(matrices[i], inverseNames[i]));
}
paramses[0].other = paramses[1].matrix;
paramses[1].other = paramses[0].matrix;

folders[0].add(paramses[0], 'show grid').onFinishChange(function() {
    mathbox.select(".grid1").set("visible", paramses[0]['show grid']);
});
folders[1].add(paramses[1], 'show grid').onFinishChange(function() {
    mathbox.select(".grid2").set("visible", paramses[1]['show grid']);
});

if(paramsQS.closed)
    gui.closed = true;

var ortho = 10000;
var mathbox = window.mathbox = mathBox({
    plugins: ['core'],
    camera: {
        near:    ortho / 4,
        far:     ortho * 4,
    },
});
if (mathbox.fallback) throw "WebGL not supported"
var three = mathbox.three;
three.renderer.setClearColor(new THREE.Color(0, 0, 0), 1);
var camera = mathbox
    .camera({
        proxy:    true,
        position: [2.2, 0, ortho],
        lookAt:   [2.2, 0, 0],
        up:       [0, 1, 0],
        fov:      Math.atan(3.5/ortho) * 360 / π,
    });
mathbox.set('focus', ortho);

var gridOpacity = 0.25;

function MakeView(params) {
    params = params || {};

    this.view = mathbox
        .cartesian({
            range: [[-range,range], [-range,range]],
            scale: [1, 1, 1],
            position: [params.pos || 0, 0, 0],
        });

    this.view
        .axis({
            classes:  ['axes'],
            axis:     1,
            end:      true,
            width:    2,
            depth:    1,
            color:    'white',
            opacity:  0.6,
            zIndex:   1,
            zOrder:   1,
            size:     3,
        })
        .axis({
            classes:  ['axes'],
            axis:     2,
            end:      true,
            width:    2,
            depth:    1,
            color:    'white',
            opacity:  0.6,
            zIndex:   1,
            zOrder:   1,
            size:     3,
        })
    ;

    this.clipped = this.view
        .shader({code: "#vertex-xyz"})
        .vertex({pass: "object"})
        .shader({
            code: "#fragment-clipping",
            uniforms: { range: { type: 'f', value: range} },
        })
        .fragment();

    this.area = this.view.area({
        width:    11,
        height:   11,
        channels: 2,
        rangeX:   [-range,range],
        rangeY:   [-range,range],
    });

    this.makeSurface = function(matrix, color, klass) {
        var transformed = this.clipped
            .transform({}, {
                matrix: function() {
                    return [matrix[0], matrix[1], 0, 0,
                            matrix[2], matrix[3], 0, 0,
                            0, 0, 1, 0,
                            0, 0, 0, 1];
                },
            })
            .surface({
                color:   color,
                points:  this.area,
                fill:    false,
                lineX:   true,
                lineY:   true,
                width:   2,
                opacity: .5,
                zOrder:  0,
                classes: [klass],
            })
        ;
    };

    // Labeled vector
    this.view
        .transform({}, {
            matrix: function() {
                    return [params.matrix[0], params.matrix[1], 0, 0,
                            params.matrix[2], params.matrix[3], 0, 0,
                            0, 0, 1, 0,
                            0, 0, 0, 1];
            },
        })
        .array({
            channels: 3,
            width:    1,
            items:    2,
            data:     [[0, 0, 0], params.vector],
        })
        .vector({
            color:  params.color,
            end:    true,
            size:   4,
            width:  3,
            zIndex: 2,
        })
        .array({
            channels: 3,
            width:    1,
            expr: function(emit) {
                emit(params.vector[0]/2, params.vector[1]/2, params.vector[2]/2);
            },
        })
        .text({
            live:  false,
            width: 1,
            data:  [params.vecname],
        })
        .label({
            outline: 1,
            background: "black",
            color:   params.color,
            offset:  [0, 25],
            size:    15,
            zIndex:  3,
        })
    ;
}

var vector = [1, 3, 0];
if(paramsQS.vec) {
    vector = paramsQS.vec.split(',').map(parseFloat);
    vector.push(0);
}

var view1 = new MakeView({
    vecname: 'x',
    color:   'rgb(0,255,0)',
    vector:  vector,
    matrix:  [1,0,0,1],
});

view1.makeSurface([1,0,0,1], 'rgb(0,255,0)', 'grid1');

// Make the vectors draggable
var draggable = new Draggable({
    view:        view1.view,
    points:      [vector],
    size:        20,
    hiliteIndex: 3,
    hiliteColor: [0, 1, 1, .75],
    hiliteSize:  20,
    onDrag:  function() { updateMatrices(); },
});
mathbox.select("#draggable-hilite").set({
    zTest:   true,
    zWrite:  true,
    zOrder:  2,
    opacity: .5,
});

var view2 = new MakeView({
    vecname: 'U(x)',
    color:   'rgb(255,0,255)',
    vector:  vector,
    matrix:  paramses[0].matrix,
    surface: true,
    pos:     2.2,
});

view2.makeSurface([1,0,0,1], 'rgb(255,0,255)', 'grid2');
view2.makeSurface(paramses[0].matrix, 'rgb(0,200,0)', 'grid1');


var view3 = new MakeView({
    vecname: 'T(U(x))',
    color:   'rgb(255,255,255)',
    vector:  vector,
    matrix:  matrix,
    surface: true,
    pos:     4.4,
});

view3.makeSurface(paramses[1].matrix, 'rgb(200,0,200)', 'grid2');
view3.makeSurface(matrix, 'rgb(0,150,0)', 'grid1');

var div = document.getElementsByClassName("mathbox-overlays")[0];
var label = self.label = document.createElement("div");
label.className = "overlay-text";
div.appendChild(label);

label.innerHTML = '<span id="matrix1-here"></span><br><br>'
    + '<span id="matrix2-here"></span><br><br>'
    + '<span id="matrix3-here"></span>';
var matrix1Span = document.getElementById("matrix1-here");
var matrix2Span = document.getElementById("matrix2-here");
var matrix3Span = document.getElementById("matrix3-here");

// Caption
var updateMatrixElt = function(span, mat, vec, incol, outcol, funcname) {
    var outVec = [
        mat[0] * vec[0] + mat[1] * vec[1],
        mat[2] * vec[0] + mat[3] * vec[1]
    ];
    katex.render(
        funcname + " = \\begin{bmatrix} "
            + mat[0].toFixed(2) + "&" + mat[1].toFixed(2) + "\\\\"
            + mat[2].toFixed(2) + "&" + mat[3].toFixed(2)
            + "\\end{bmatrix}"
            + "\\color{" + incol + "}{"
            + "\\begin{bmatrix}"
            + vec[0].toFixed(2) + "\\\\"
            + vec[1].toFixed(2)
            + "\\end{bmatrix}} = \\color{" + outcol + "}{"
            + "\\begin{bmatrix}"
            + outVec[0].toFixed(2) + "\\\\"
            + outVec[1].toFixed(2)
            + "\\end{bmatrix}}",
        span);
    return outVec;
};

var updateMatrices = function() {
    var vec = updateMatrixElt(
        matrix1Span, paramses[0].matrix, vector, "#00ff00", "#ff00ff",
        "U(\\color{#00ff00}{x})");
    updateMatrixElt(
        matrix2Span, paramses[1].matrix, vec, "#ff00ff", "#ffffff",
        "T(\\color{#ff00ff}{U(x)})");
    updateMatrixElt(
        matrix3Span, matrix, vector, "#00ff00", "#ffffff",
        "T(U(\\color{#00ff00}{x}))");
}

updateMatrices();
