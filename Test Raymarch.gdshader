shader_type spatial;

render_mode unshaded, depth_draw_opaque, cull_front;

varying vec3 worldPos;
varying vec3 objPos;

float sdSphere(vec3 pos, float r) {
	return length(pos) - r;
}

float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

vec3 rotateY(vec3 p, float deg) {
	float rad = deg * PI/180.0;
	return mat3(vec3(cos(rad), 0, -sin(rad)), vec3(0,1,0), vec3(sin(rad), 0, cos(rad))) * p;
}

vec3 rotateX(vec3 p, float deg) {
	float rad = deg * PI/180.0;
	return mat3(vec3(1, 0, 0), vec3(0,cos(rad),sin(rad)), vec3(0, -sin(rad), cos(rad))) * p;
}

#define FRACTAL_ITER 6
#define MAX_STEPS 1000
#define MAX_DIST 1000.0
#define SURFACE_DIST .0001
float getDist(vec3 inpos) {
	//pos = mod(pos, 2.0);
	//pos = pos;
	
	vec3 pos = inpos - objPos;
	pos /= 5.0;
	
	for (int i = 0; i < FRACTAL_ITER; i++) {
		/*
		*/
		pos *= 3.0;
		pos.z = abs(pos.z);
		pos.z -= 1.0;
		pos.y = abs(pos.y);
		pos.y -= 1.0;
		pos.x = abs(pos.x);
		pos.x -= 1.0 + sin(TIME) / 8.;
		pos = rotateX(pos, 45);
		pos.y = abs(pos.y);
		pos = rotateX(pos, -45.0);
		pos = rotateY(pos, 45.0);
		pos.z = abs(pos.z);
		pos = rotateY(pos, -45);
		pos.x += .5;
		pos.x = abs(pos.x);
		pos.x -= .5;
	}
	float output = sdBox(pos, vec3(.5))/* + sin(TIME*3.0+pos.x*16.0)/10.0*/;
	for (int i = 0; i < FRACTAL_ITER; i++)
		output /= 3.0;
	
	output *= 5.0;
	
	float altOutput = sdBox(inpos, vec3(2.5));
	float lerpOutput = mix(output, altOutput, /*clamp(pow(sin(TIME/4.0),4.0),0,1)*/ 0);
	return lerpOutput;
}

vec3 getNormal(vec3 p) {
    float d = getDist(p);
    vec2 e = vec2(SURFACE_DIST, 0);

    vec3 n = d - vec3(
        getDist(p-e.xyy),
        getDist(p-e.yxy),
        getDist(p-e.yyx)
    );

    return normalize(n);
}

float getLight(vec3 p) {
    vec3 l = normalize(vec3(.3,-.5,-1));
    vec3 n = getNormal(p);

    float dif = dot(n, l);

    return dif;
}

struct raymarch {
	float d;
	vec3 p;
	bool hit;
	int steps;
};

raymarch rayMarch(vec3 ro, vec3 rd) {
	raymarch result;
	float d0 = 0.0;
	for (int i = 0; i < MAX_STEPS; i++) {
		vec3 p = ro+d0*rd;
		float dS = max(getDist(p),0.00001);
		d0 += dS;
		if (dS < SURFACE_DIST) {
			result.hit = true;
			result.d = d0;
			result.p = ro+d0*rd;
			result.steps = i;
			return result;
		}
		if (d0 > MAX_DIST) {
			result.hit = false;
			return result;
		}
	}
	result.hit = true;
	result.d = d0;
	result.p = ro+d0*rd;
	result.steps = MAX_STEPS;
	return result;
}

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX,1)).xyz;
	objPos = MODEL_MATRIX[3].xyz;
//	vec4 adjustedPosition = MODEL_MATRIX * vec4(VERTEX,1);
//	vec3 actualCamDir = vec3(VIEW_MATRIX[0].z,VIEW_MATRIX[1].z,VIEW_MATRIX[2].z);
//	actualCamDir = normalize(actualCamDir);
//	float camForwardDist = dot((adjustedPosition.xyz - CAMERA_POSITION_WORLD), -actualCamDir);
//
//	float nearPlane = PROJECTION_MATRIX[2].w / (PROJECTION_MATRIX[2].z - 1.0);
//	//COLOR = vec4(vec3(camForwardDist),1.0);
//	if (camForwardDist < nearPlane) {
//		//adjustedPosition.z += 2.0;
//		adjustedPosition.xyz += actualCamDir * (camForwardDist - nearPlane);
//	}
//	worldPos = adjustedPosition.xyz;
//	adjustedPosition = VIEW_MATRIX * adjustedPosition;
//	adjustedPosition = PROJECTION_MATRIX * adjustedPosition;
//	POSITION = adjustedPosition;
}

void fragment() {
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 rd = normalize(worldPos - ro);
	raymarch rayPass = rayMarch(ro,rd);
	if (!rayPass.hit) discard;
	float light = getLight(rayPass.p);
	light = max(.1, light);
	float occ = float(rayPass.steps) / float(MAX_STEPS);
	light *= 1.0 - 10.0 * occ;
	light = clamp(light, 0, 1);
	ALBEDO = vec3(light);
	
	
	// Based on https://stackoverflow.com/a/12904072
	vec4 eye_space_pos = VIEW_MATRIX * vec4(rayPass.p, 1.0);
	vec4 clip_space_pos = PROJECTION_MATRIX * eye_space_pos;

	float ndc_depth = clip_space_pos.z / clip_space_pos.w;

	float far=1.0; float near=-1.0;
	float depth = (((far-near) * ndc_depth) + near + far) / 2.0;
	
	DEPTH = depth;
}
