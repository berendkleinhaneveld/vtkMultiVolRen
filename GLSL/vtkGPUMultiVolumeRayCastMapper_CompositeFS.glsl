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

//carlos
uniform sampler3D dataSetTexture2;
uniform sampler1D opacityTexture2;
// Change-of-coordinate matrix from texture coord of first volume
// to texture coord of second volume
uniform mat4 P1toP2;

// Properties that can be set from the interface
uniform int blendType;
uniform float lowerBound1;
uniform float lowerBound2;
uniform float upperBound1;
uniform float upperBound2;
uniform float brightness1;
uniform float brightness2;
// Shader types of the fixed and moving datasets
uniform int shaderType1;
uniform int shaderType2;

uniform sampler1D mask2ColorTexture;

// Bounds from the fixed dataset
uniform vec3 lowBounds;
uniform vec3 highBounds;

// Bounds from the moving dataset
uniform vec3 lowBounds2;
uniform vec3 highBounds2;

// Entry position (global scope)
vec3 pos;
vec3 pos2;
// Incremental vector in texture space (global scope)
vec3 rayDir;

float tMax;

vec4 fColor;
float fValue1;
float fValue2;
vec4 mColor;
float mValue1;
float mValue2;
vec4 dColor;
float dValue;

// from cropping vs no cropping
vec4 initialColor();

// from 1 vs 4 component shader.
float scalarFromValue(vec4 value);
vec4 colorFromValue(vec4 value);
vec4 colorFromValue2(vec4 value);

// from noshade vs shade.
void initShade();
vec4 shade(vec4 value);
vec4 shade2(vec4 value);

// Custom shader passes
void shadeDVR(int volumeNr, vec4 value, float opacity, inout vec4 destColor, inout float currentOpacity);
void shadeMIP(int volumeNr, vec4 value, float opacity, inout vec4 maxColor, inout float maxOpacity);
void shadeMIDA(int volumeNr, vec4 value, float opacity, inout vec4 accumulatedColor, inout float accumulatedOpacity, inout float currentMax);
void traceNormal(void);
void traceDifference(void);

void trace(void) {
	if (blendType == 0) {
		traceNormal();
	} else if (blendType == 1) {
		traceDifference();
	}
}

void traceNormal(void) {
	float t = 0.0;
	
	initShade();

	// Create temporary values for each of the
	// volumes. They can be used to store temporary
	// values during ray tracing.
	fColor = initialColor();
	fValue1 = 0.0;
	fValue2 = 0.0;
	mColor = initialColor();
	mValue1 = 0.0;
	mValue2 = 0.0;

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
		pos2 = vec3(P1toP2 * vec4(pos, 1));

		// Sample the first dataset
		if (shaderType1 == 0) {
			shadeDVR(0, valueVector, opacity, fColor, fValue1);
		} else if (shaderType1 == 1) {
			shadeMIP(0, valueVector, opacity, fColor, fValue1);
		} else if (shaderType1 == 2) {
			shadeMIDA(0, valueVector, opacity, fColor, fValue1, fValue2);
		}

		if (all(greaterThanEqual(pos2, lowBounds2))
			&& all(lessThanEqual(pos2, highBounds2)))
		{
			vec4 valueVector2 = texture3D(dataSetTexture2, pos2);
			float valueScalar2 = scalarFromValue(valueVector2);
			float opacity2 = texture1D(opacityTexture2, valueScalar2).a;

			// Sample the second dataset
			if (shaderType2 == 0 && shaderType1 == 0) {
				shadeDVR(1, valueVector2, opacity2, fColor, fValue1);
			} else if (shaderType2 == 0) {
				shadeDVR(1, valueVector2, opacity2, mColor, mValue1);
			} else if (shaderType2 == 1) {
				shadeMIP(1, valueVector2, opacity2, mColor, mValue1);
			} else {
				shadeMIDA(1, valueVector2, opacity2, mColor, mValue1, mValue2);
			}
		}

		pos = pos + rayDir;
		t += 1.0;

		bool shouldContinue = true;
		if (shaderType1 == 0 && shaderType2 == 0) {
			shouldContinue = (1.0 - fValue1) >= 0.0039;
		} else if (shaderType1 != 0 && shaderType2 == 0) {
			shouldContinue = (1.0 - mValue1) >= 0.0039;
		}

		inside = t < tMax && all(greaterThanEqual(pos, lowBounds))
			&& all(lessThanEqual(pos, highBounds))
			&& shouldContinue;
	}

	vec4 color1 = fColor;
	if (shaderType1 == 2) {
		color1 = fColor * brightness1;
	}
	color1.a = fValue1;
	vec4 color2 = mColor;
	if (shaderType2 == 2) {
		color2 = fColor * brightness2;
	}
	color2.a = mValue1;
	
	// Blend the colors together based on render types
	// Blend type 0: render with depth
	// Blend type 1: add the final images right on top of each other
	// blend type 2: difference between volumes (especially applicable to dvr)
	// Blend type 3: similarity between volumes
	gl_FragColor = color1 + color2;
}

void traceDifference(void) {
	float t = 0.0;
	
	initShade();

	// Create temporary values for each of the
	// volumes. They can be used to store temporary
	// values during ray tracing.
	fColor = initialColor();
	fValue1 = 0.0;
	fValue2 = 0.0;
	mColor = initialColor();
	mValue1 = 0.0;
	mValue2 = 0.0;
	dColor = initialColor();
	dValue = 0.0;

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
		/* 
		Calculate the difference between two datasets. For every voxel that lies in
		both the first and the second dataset the difference between the colors will
		be calculated and added to the dColor/dValue.
		Stop condition is at the end of the first dataset, or when dValue is 1.0.
		*/

		// First check to see if we are also in the second dataset
		pos2 = vec3(P1toP2 * vec4(pos, 1));
		if (all(greaterThanEqual(pos2, lowBounds2))
			&& all(lessThanEqual(pos2, highBounds2)))
		{
			vec4 valueVector = texture3D(dataSetTexture, pos);
			float valueScalar = scalarFromValue(valueVector);
			float opacity = texture1D(opacityTexture, valueScalar).a;

			// Sample the first dataset
			shadeDVR(0, valueVector, opacity, fColor, fValue1);

			vec4 valueVector2 = texture3D(dataSetTexture2, pos2);
			float valueScalar2 = scalarFromValue(valueVector2);
			float opacity2 = texture1D(opacityTexture2, valueScalar2).a;

			// Sample the second dataset
			shadeDVR(1, valueVector2, opacity2, mColor, mValue1);

			vec4 diffColor = abs(fColor - mColor);
			float diffValue = abs(fValue1 - mValue1);

			// TODO: replace 0.1 with a decent multiplier, to be set
			// by an interface slider
			diffColor = (diffColor * diffValue) * 0.1;
			dColor = dColor + diffColor;
			float remainOpacity = 1.0 - dValue;
			dValue = dValue + (diffValue * remainOpacity) * 0.1;

			// Reset fColor and mColor
			fColor = initialColor();
			fValue1 = 0.0;
			mColor = initialColor();
			mValue1 = 0.0;
		}
		
		pos = pos + rayDir;
		t += 1.0;

		// Halt when you dValue is saturated
		bool shouldContinue = (1.0 - dValue) >= 0.0039;
		inside = t < tMax && all(greaterThanEqual(pos, lowBounds))
			&& all(lessThanEqual(pos, highBounds))
			&& shouldContinue;
	}
	
	// Blend the colors together based on render types
	// Blend type 0: render with depth
	// Blend type 1: add the final images right on top of each other
	// blend type 2: difference between volumes (especially applicable to dvr)
	// Blend type 3: similarity between volumes
	gl_FragColor = dColor + dValue;
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
		if (volumeNr == 0) {
			color = shade(value);
		} else {
			color = shade2(value);
		}
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
	float shadedValue;
	float lowerBound;
	float upperBound;
	if (volumeNr == 0) {
		shadedValue = shade(value).r;
		lowerBound = lowerBound1;
		upperBound = upperBound1;
	} else {
		shadedValue = shade2(value).r;
		lowerBound = lowerBound2;
		upperBound = upperBound2;
	}
	if (shadedValue > maxColor.r && shadedValue >= lowerBound && shadedValue <= upperBound)
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
		float color;
		if (volumeNr == 0) {
			color = shade(value).r;
		} else {
			color = shade2(value).r;
		}
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
