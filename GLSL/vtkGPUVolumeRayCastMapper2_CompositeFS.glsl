/*========================================================================= 

  Program:   Visualization Toolkit
  Module:    vtkGPUVolumeRayCastMapper_CompositeFS.glsl

  Copyright (c) Ken Martin, Will Schroeder, Bill Lorensen
  All rights reserved.
  See Copyright.txt or http://www.kitware.com/Copyright.htm for details.

	 This software is distributed WITHOUT ANY WARRANTY; without even
	 the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
	 PURPOSE.  See the above copyright notice for more information.

 =========================================================================*/

// Fragment program part with ray cast and composite method.

#version 110

uniform sampler3D dataSetTexture;
uniform sampler1D opacityTexture;

// Properties that can be set from the interface
uniform int shaderType;
uniform float lowerBound;
uniform float upperBound;
uniform float window;
uniform float level;
uniform float brightness;

uniform vec3 lowBounds;
uniform vec3 highBounds;

// Entry position (global scope)
vec3 pos;
// Incremental vector in texture space (global scope)
vec3 rayDir;

float tMax;

// from cropping vs no cropping
vec4 initialColor();

// from 1 vs 4 component shader.
float scalarFromValue(vec4 value);
vec4 colorFromValue(vec4 value);
vec4 colorFromValue2(vec4 value);

// from noshade vs shade.
void initShade();
vec4 shade(vec4 value);

vec4 fColor;
float fValue1;
float fValue2;

// Custom shader passes
void shadeDVR(int volumeNr, vec4 value, float opacity, inout vec4 destColor, inout float currentOpacity);
void shadeMIP(int volumeNr, vec4 value, float opacity, inout vec4 maxColor, inout float maxOpacity);
void shadeMIDA(int volumeNr, vec4 value, float opacity, inout vec4 accumulatedColor, inout float accumulatedOpacity, inout float currentMax);

void trace(void) {
	// Temp color can be used to put blended values
	// into during rendering
	float t = 0.0;

	initShade();

	// Create temporary values for each of the
	// volumes. They can be used to store temporary
	// values during ray tracing.
	// fColor = vec4(0.0);
	fColor = initialColor();
	fValue1 = 0.0;
	fValue2 = 0.0;

	// MIDA:
	// * accumulatedColor (vec4)	- Color
	// * accumulatedOpacity (float)	- Value1
	// * currentMax (float)			- Value2

	// MIP:
	// * maxColor (vec4)			- Color
	// * maxOpacity (float)			- Value1

	// DVR:
	// * currentColor (vec4)		- Color
	// * currentOpacity (float)		- Value1

	bool inside = true;
	while (inside) {
		vec4 valueVector = texture3D(dataSetTexture, pos);
		float valueScalar = scalarFromValue(valueVector);
		float opacity = texture1D(opacityTexture, valueScalar).a;

		// Sample the dataset
		if (shaderType == 0) {
			shadeDVR(0, valueVector, opacity, fColor, fValue1);
		} else if (shaderType == 1) {
			shadeMIP(0, valueVector, opacity, fColor, fValue1);
		} else if (shaderType == 2) {
			shadeMIDA(0, valueVector, opacity, fColor, fValue1, fValue2);
		}

		pos = pos + rayDir;
		t += 1.0;

		bool shouldContinue = true;
		if (shaderType == 0) {
			shouldContinue = (1.0 - fValue1) >= 0.0039;
		}

		inside = t < tMax && all(greaterThanEqual(pos, lowBounds))
			&& all(lessThanEqual(pos, highBounds))
			&& shouldContinue;
	}
	
	gl_FragColor = fColor;
	gl_FragColor.a = fValue1;
}

/**
 * value: value from texture
 * opacity: opacity from texture
 * inout remainOpacity: remaining opacity in the destination color
 * inout destColor: color that this shader pass adds to
 */
void shadeDVR(int volumeNr, vec4 value, float opacity, inout vec4 destColor, inout float currentOpacity) {
	vec4 color = vec4(0.0);
	if (opacity > 0.0)
	{
		color = shade(value);
		float remainOpacity = 1.0 - currentOpacity;
		color = color * opacity;
		destColor = destColor + color * remainOpacity;
		remainOpacity = remainOpacity * (1.0 - opacity);
		currentOpacity = 1.0 - remainOpacity;
	}
}

/**
 * value: value from texture
 * opacity: opacity from texture
 * inout maxColor: maximum color at any time
 * inout maxOpacity: opacity that goes together with the maximum color
 */
void shadeMIP(int volumeNr, vec4 value, float opacity, inout vec4 maxColor, inout float maxOpacity) {
	float valueScalar = scalarFromValue(value);
	if (valueScalar > maxColor.r)
	{
		maxColor = vec4(valueScalar);
		maxOpacity = opacity;
	}
}

/**
 * value: value from texture
 * opacity: opacity from texture
 * inout accumulatedColor: maximum color at any time
 * inout accumulatedOpacity: opacity that goes together with the maximum color
 * inout currentMax:
 */
void shadeMIDA(int volumeNr, vec4 value, float opacity, inout vec4 accumulatedColor, inout float accumulatedOpacity, inout float currentMax) {
	float valueScalar = scalarFromValue(value);
	if (valueScalar > currentMax)
	{
		// Get the color
		float color = shade(value).r;
		// Calculate a difference measure
		float difference = valueScalar - currentMax;
		float factor = 1.0 - difference;

		// Update the accumulated values
		accumulatedColor = accumulatedColor * factor + (1.0 - accumulatedOpacity * factor) * opacity * color;
		accumulatedOpacity = accumulatedOpacity * factor + (1.0 - accumulatedOpacity * factor) * opacity;

		// Update the current maximum value
		currentMax = valueScalar;
	}
}
