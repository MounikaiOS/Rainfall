/*
 Copyright 2017-present The Material Motion Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MotionInterchange.h"

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

// Returns a basic animation configured with the provided timing and scale factor.
FOUNDATION_EXPORT
CABasicAnimation *MDMAnimationFromTiming(MDMMotionTiming timing, CGFloat timeScaleFactor);

// Attempts to configure the provided animation to be additive and, if the animation is a spring
// animation, will extract the initial velocity from the timing and apply it to the animation.
//
// Not all animation value types support being additive. If an animation's value type was not
// supported, the animation's values will not be modified.
//
// If the from and to values of the animation match then the behavior is undefined.
FOUNDATION_EXPORT void MDMConfigureAnimation(CABasicAnimation *animation,
                                             BOOL wantsAdditive,
                                             MDMMotionTiming timing);
