////////////////////////////////////////////////////////////////////////////////
// GLOBAL VARS
////////////////////////////////////////////////////////////////////////////////

var EPS     = 0.001,
    PI      = 3.1415926535897932,
    HALFPI  = 1.5707963267948966;

var container;
var sWidth, sHeight;
var gRenderer, gStats;
var gCamera, gScene, gControls, gViewQuad;
var gAspect;
var dt = 0.02;

var lambert1 = new THREE.MeshLambertMaterial({color: 0xCC0000});

var gLightP;
var gLightI = 1.0;

var gUniforms;

////////////////////////////////////////////////////////////////////////////////
// MOUSE CALLBACK
////////////////////////////////////////////////////////////////////////////////

var gLastMouseX = 0,
    gLastMouseY = 0,
    gMouseDown  = false;
    
function mouseDown(event) {
  gMouseDown = true;
  gLastMouseX = event.clientX;
  gLastMouseY = event.clientY;
}
function mouseUp(event) {
  gMouseDown = false;
}
function mouseMove(event) {
  /*
  if(gMouseDown) {
    var thisMouseX = event.clientX;
    var thisMouseY = event.clientY;
  
    gRoot.rotation.y += (thisMouseX - gLastMouseX) * 0.01;
    gRoot.rotation.x += (thisMouseY - gLastMouseY) * 0.01;
    
    gLastMouseY = thisMouseY;
    gLastMouseX = thisMouseX;
  }
  */
  
  if(gMouseDown) {
    $("#cam_pos").html("<b>cam_position:</b> "+gCamera2.position.x+", "+gCamera2.position.y+", "+gCamera2.position.z);
    $("#cam_up").html("<b>cam_up:</b> "+gCamera2.up.x+", "+gCamera2.up.y+", "+gCamera2.up.z);
  }
}

function initKeyboardEvents() {
  
  $(document).keypress(function(event) {
    var key = String.fromCharCode(event.which);
    console.log("keypress "+key)    
      
    if (key == "R") {
      gCamera2.position.set(0,0,10);
      gControls.target.set(0,0,0);
      gCamera2.up.set(0,1,0);
      console.log("reset camera");
    }   
    else if (key == "S") {
      var url = $('#webgl-container canvas').get(0).toDataURL();
      window.open(url,
                  "Screen Capture",
                  "width="+sWidth+", height="+sHeight+", \
                          scrollbars=no, resizable=yes");
      console.log("output image in new window");
    }
    else if (key == "Q") {
      $("div#menu").toggle();
    }
  
  });

}

////////////////////////////////////////////////////////////////////////////////
// INITIALIZATION
////////////////////////////////////////////////////////////////////////////////

function initScene() {
  gLightP = new THREE.Vector3(2.0, 10.0, 5.0);
}

/* INIT GL */
function initTHREE() {
  sWidth = window.innerWidth;
  sHeight = window.innerHeight;
  
  container = $('#webgl-container');
  
  container.mousedown(mouseDown);
  container.mouseup(mouseUp);
  container.mousemove(mouseMove);
  
  // setup WebGL renderer
  gRenderer = new THREE.WebGLRenderer();
  gRenderer.setSize(sWidth, sHeight);
  gRenderer.setClearColorHex(0x000000, 1);
  container.append(gRenderer.domElement);
  
  // camera to render, orthogonal (fov=0)
  gCamera = new THREE.OrthographicCamera(-.5, .5, .5, -.5, -1, 1);
  
  // scene for rendering
  gScene = new THREE.Scene();
  gScene.add(gCamera);
  
  // camera for raytracing
  gCamera2 = new THREE.PerspectiveCamera(
    30,
    sWidth / sHeight,
    1,
    1e3 );
  gCamera2.position.z = 10;
  
  // controls for camera
  gControls = new THREE.TrackballControls(gCamera2, container.get(0));
  gControls.rotateSpeed = 1.0;
  gControls.zoomSpeed = 1.2;
  gControls.panSpeed = 1.0;    
  gControls.dynamicDampingFactor = 0.3;
  gControls.staticMoving = false;
  gControls.noZoom = false;
  gControls.noPan = false;
  
  gUniforms = {
    uCamPos:    {type: "v3", value: gCamera2.position},
    uCamCenter: {type: "v3", value: gControls.target},
    uCamUp:     {type: "v3", value: gCamera2.up},
    uAspect:    {type: "f", value: sWidth/sHeight},
    uTime:      {type: "f", value: 0.0},
    uLightP:    {type: "v3", value: gLightP}
  };
  
  // compile shader
  var shader = new THREE.ShaderMaterial({
    uniforms:       gUniforms,
    vertexShader:   $("#shader-vs").text(),
    fragmentShader: $("#shader-fs").text()
  });
  
  // setup plane in scene for rendering
  gViewQuad = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), shader);
  var node = new THREE.Object3D();
  node.rotation.x = HALFPI;
  node.add(gViewQuad);
  gScene.add(node);
  
  recompileShader();
  
  $("#loading").hide();
  
  // stats ui
  gStats = new Stats();
  gStats.domElement.style.position = 'absolute';
  gStats.domElement.style.top = '0px';
  container.append( gStats.domElement );
}

function recompileShader() {    
  var addString =
    "#define MAX_STEPS " + $("#menu select[name=maxsteps]").val() + "\n";
  
  // render mode
  var renderMode = $("#submenu-render input[type=radio]:checked").val().toUpperCase();
  addString += "#define RENDER_" + renderMode + "\n";
  
  // obj mode
  var sceneObj = $("#submenu-obj input[type=radio]:checked").val().toUpperCase();
  addString += "#define DE_" + sceneObj + "\n";
  
  // checkbox options
  $("#menu input[type=checkbox]:checked").each( function() {
    var optionString = this.name.toUpperCase();
    addString += "#define " + optionString + "\n";
  });
  
  console.log("recompile shader:\n"+addString);
  
  gViewQuad.material.fragmentShader = addString + $("#shader-fs").text();
  gViewQuad.material.needsUpdate = true;
}

/* UPDATE */
function update() {  
  gStats.update();
  gControls.update();
  gRenderer.render(gScene, gCamera);
  
  gUniforms.uTime.value += dt;

  requestAnimationFrame(update);
}

function init() {
  initScene();
  initTHREE();
  initKeyboardEvents(); 
  requestAnimationFrame(update);
  
  $("#loading").hide();
}

function infoClose() {
  $("#info").addClass("hidden");
  $("#menu .submenu").removeClass("hidden");
}

/* DOC READY */
$(document).ready(function() {
  // load shader strings
  $("#shader-fs").load("shader/render.glsl", init);
});