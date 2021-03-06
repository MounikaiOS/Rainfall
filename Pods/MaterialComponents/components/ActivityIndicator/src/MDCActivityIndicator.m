/*
 Copyright 2016-present the Material Components for iOS authors. All Rights Reserved.

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

#import "MDCActivityIndicator.h"

#import <QuartzCore/QuartzCore.h>

#import "MDFInternationalization.h"
#import "MaterialApplication.h"
#import "MotionAnimator.h"
#import "private/MDCActivityIndicatorMotionSpec.h"
#import "private/MDCActivityIndicator+Private.h"
#import "private/MaterialActivityIndicatorStrings.h"
#import "private/MaterialActivityIndicatorStrings_table.h"
#import "MaterialPalettes.h"

static const NSInteger kTotalDetentCount = 5;
static const NSTimeInterval kAnimateOutDuration = 0.1f;
static const CGFloat kCycleRotation = 3.0f / 2.0f;
static const CGFloat kOuterRotationIncrement =
    (1.0f / kTotalDetentCount) * (CGFloat)M_PI;
static const CGFloat kSpinnerRadius = 12.f;
static const CGFloat kStrokeLength = 0.75f;

#ifndef CGFLOAT_EPSILON
#if CGFLOAT_IS_DOUBLE
#define CGFLOAT_EPSILON DBL_EPSILON
#else
#define CGFLOAT_EPSILON FLT_EPSILON
#endif
#endif

// The Bundle for string resources.
static NSString *const kBundle = @"MaterialActivityIndicator.bundle";

/**
 Total rotation (outer rotation + stroke rotation) per _cycleCount. One turn is 2.0f.
 */
static const CGFloat kSingleCycleRotation =
    2 * kStrokeLength + kCycleRotation + 1.0f / kTotalDetentCount;

@interface MDCActivityIndicator ()

/**
 The minimum stroke difference to use when collapsing the stroke to a dot. Based on current
 radius and stroke width.
 */
@property(nonatomic, assign, readonly) CGFloat minStrokeDifference;

/**
 The index of the current stroke color in the @c cycleColors array.

 @note Subclasses can change this value to start the spinner at a different color.
 */
@property(nonatomic, assign) NSUInteger cycleColorsIndex;

/**
 The current cycle count.
 */
@property(nonatomic, assign, readonly) NSInteger cycleCount;

/**
 The cycle index at which to start the activity spinner animation. Default is 0, which corresponds
 to the top of the spinner (12 o'clock position). Spinner cycle indices are based on a 5-point
 star.
 */
@property(nonatomic, assign) NSInteger cycleStartIndex;

/**
 The outer layer that handles cycle rotations and houses the stroke layer.
 */
@property(nonatomic, strong, readonly, nullable) CALayer *outerRotationLayer;

/**
 The shape layer that handles the animating stroke.
 */
@property(nonatomic, strong, readonly, nullable) CAShapeLayer *strokeLayer;

/**
 The shape layer that shows a faint, circular track along the path of the stroke layer. Enabled
 via the trackEnabled property.
 */
@property(nonatomic, strong, readonly, nullable) CAShapeLayer *trackLayer;

@end

@implementation MDCActivityIndicator {
  BOOL _animatingOut;
  BOOL _animationsAdded;
  BOOL _animationInProgress;
  BOOL _backgrounded;
  BOOL _cycleInProgress;
  CGFloat _currentProgress;
  CGFloat _lastProgress;

  MDMMotionAnimator *_animator;
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self commonMDCActivityIndicatorInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    [self commonMDCActivityIndicatorInit];
    // TODO: Overwrite cycleColors if the value is present in the coder
    // https://github.com/material-components/material-components-ios/issues/1530
  }
  return self;
}

+ (void)initialize {
  // Ensure we do not set the UIAppearance proxy if subclasses are initialized
  if (self == [MDCActivityIndicator class]) {
    [MDCActivityIndicator appearance].cycleColors = [MDCActivityIndicator defaultCycleColors];
  }
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  [self applyPropertiesWithoutAnimation:^{
    // Resize and recenter rotation layer.
    _outerRotationLayer.bounds = self.bounds;
    _outerRotationLayer.position =
        CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);

    _strokeLayer.bounds = _outerRotationLayer.bounds;
    _strokeLayer.position = _outerRotationLayer.position;

    [self updateStrokePath];
  }];
}

- (void)commonMDCActivityIndicatorInit {
  // Register notifications for foreground and background if needed.
  [self registerForegroundAndBackgroundNotificationObserversIfNeeded];

  // The activity indicator reflects the passage of time (a spatial semantic context) and so
  // will not be mirrored in RTL languages.
  self.mdf_semanticContentAttribute = UISemanticContentAttributeSpatial;

  _animator = [[MDMMotionAnimator alloc] init];
  _animator.additive = NO;

  _cycleStartIndex = 0;
  _indicatorMode = MDCActivityIndicatorModeIndeterminate;

  // Property defaults.
  _radius = kSpinnerRadius;
  _strokeWidth = 2.0f;

  // Colors.
  _cycleColorsIndex = 0;
  _cycleColors = [MDCActivityIndicator defaultCycleColors];

  // Track layer.
  _trackLayer = [CAShapeLayer layer];
  _trackLayer.lineWidth = _strokeWidth;
  _trackLayer.fillColor = [UIColor clearColor].CGColor;
  [self.layer addSublayer:_trackLayer];
  _trackLayer.hidden = YES;

  // Rotation layer.
  _outerRotationLayer = [CALayer layer];
  [self.layer addSublayer:_outerRotationLayer];

  // Stroke layer.
  _strokeLayer = [CAShapeLayer layer];
  _strokeLayer.lineWidth = _strokeWidth;
  _strokeLayer.fillColor = [UIColor clearColor].CGColor;
  _strokeLayer.strokeStart = 0;
  _strokeLayer.strokeEnd = 0;
  [_outerRotationLayer addSublayer:_strokeLayer];
}

#pragma mark - UIView

- (void)willMoveToWindow:(UIWindow *)newWindow {
  // If the activity indicator is removed from the window, we should
  // immediately stop animating, otherwise it will start chewing up CPU.
  if (!newWindow) {
    [self actuallyStopAnimating];
  } else if (_animating && !_backgrounded) {
    [self actuallyStartAnimating];
  }
}

- (CGSize)intrinsicContentSize {
  CGFloat edge = 2 * _radius + _strokeWidth;
  return CGSizeMake(edge, edge);
}

- (CGSize)sizeThatFits:(__unused CGSize) size {
  CGFloat edge = 2 * _radius + _strokeWidth;
  return CGSizeMake(edge, edge);
}

#pragma mark - Public methods

- (void)startAnimating {
  if (_animatingOut) {
    if ([_delegate respondsToSelector:@selector(activityIndicatorAnimationDidFinish:)]) {
      [_delegate activityIndicatorAnimationDidFinish:self];
    }
    [self removeAnimations];
  }

  if (_animating) {
    return;
  }

  _animating = YES;

  if (self.window && !_backgrounded) {
    [self actuallyStartAnimating];
  }
}

- (void)stopAnimating {
  if (!_animating) {
    return;
  }

  _animating = NO;

  [self animateOut];
}

- (void)stopAnimatingImmediately {
  if (!_animating) {
    return;
  }

  _animating = NO;

  [self actuallyStopAnimating];

  if ([_delegate respondsToSelector:@selector(activityIndicatorAnimationDidFinish:)]) {
    [_delegate activityIndicatorAnimationDidFinish:self];
  }
}

- (void)resetStrokeColor {
  _cycleColorsIndex = 0;

  [self updateStrokeColor];
}

- (void)setStrokeColor:(UIColor *)strokeColor {
  _strokeLayer.strokeColor = strokeColor.CGColor;
  _trackLayer.strokeColor = [strokeColor colorWithAlphaComponent:0.3f].CGColor;
}

- (void)setIndicatorMode:(MDCActivityIndicatorMode)indicatorMode {
  if (_indicatorMode == indicatorMode) {
    return;
  }
  _indicatorMode = indicatorMode;
  if (_animating && !_animationInProgress) {
    switch (indicatorMode) {
      case MDCActivityIndicatorModeDeterminate:
        [self addTransitionToDeterminateCycle];
        break;
      case MDCActivityIndicatorModeIndeterminate:
        [self addTransitionToIndeterminateCycle];
        break;
    }
  }
}

- (void)setIndicatorMode:(MDCActivityIndicatorMode)mode animated:(__unused BOOL)animated {
  [self setIndicatorMode:mode];
}

- (void)setProgress:(float)progress {
  _progress = MAX(0.0f, MIN(progress, 1.0f));
  if (_progress == _currentProgress) {
    return;
  }
  if (_animating && !_animationInProgress) {
    switch (_indicatorMode) {
      case MDCActivityIndicatorModeDeterminate:
        // Currently animating the determinate mode but no animation queued.
        [self addProgressAnimation];
        break;
      case MDCActivityIndicatorModeIndeterminate:
        break;
    }
  }
}

#pragma mark - Properties

- (void)setStrokeWidth:(CGFloat)strokeWidth {
  _strokeWidth = strokeWidth;
  _strokeLayer.lineWidth = _strokeWidth;
  _trackLayer.lineWidth = _strokeWidth;

  [self updateStrokePath];
}

- (void)setRadius:(CGFloat)radius {
  _radius = MIN(MAX(radius, 5.0f), 72.0f);

  [self updateStrokePath];
}

- (void)setTrackEnabled:(BOOL)trackEnabled {
  _trackEnabled = trackEnabled;

  _trackLayer.hidden = !_trackEnabled;
}

#pragma mark - Private methods

/**
 If this class is not being run in an extension, register for foreground changes and initialize
 the app background state in case UI is created when the app is backgrounded. (Extensions always
 return UIApplicationStateBackground for |[UIApplication sharedApplication].applicationState|.)
 */
- (void)registerForegroundAndBackgroundNotificationObserversIfNeeded {
  if ([UIApplication mdc_isAppExtension]) {
    return;
  }

  _backgrounded =
      [UIApplication mdc_safeSharedApplication].applicationState == UIApplicationStateBackground;
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self
                         selector:@selector(controlAnimatingOnForegroundChange:)
                             name:UIApplicationWillEnterForegroundNotification
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(controlAnimatingOnForegroundChange:)
                             name:UIApplicationDidEnterBackgroundNotification
                           object:nil];
}

- (void)controlAnimatingOnForegroundChange:(NSNotification *)notification {
  // Stop or restart animating if the app has a foreground change.
  _backgrounded = [notification.name isEqualToString:UIApplicationDidEnterBackgroundNotification];
  if (_animating) {
    if (_backgrounded) {
      [self actuallyStopAnimating];
    } else if (self.window) {
      [self actuallyStartAnimating];
    }
  }
}

- (void)actuallyStartAnimating {
  if (_animationsAdded) {
    return;
  }
  _animationsAdded = YES;
  _cycleCount = _cycleStartIndex;

  [self applyPropertiesWithoutAnimation:^{
    _strokeLayer.strokeStart = 0.0f;
    _strokeLayer.strokeEnd = 0.001f;
    _strokeLayer.lineWidth = _strokeWidth;
    _trackLayer.lineWidth = _strokeWidth;

    [self resetStrokeColor];
    [self updateStrokePath];
  }];

  switch (_indicatorMode) {
    case MDCActivityIndicatorModeIndeterminate:
      [self addStrokeRotationCycle];
      break;
    case MDCActivityIndicatorModeDeterminate:
      [self addProgressAnimation];
      break;
  }
}

- (void)actuallyStopAnimating {
  if (!_animationsAdded) {
    return;
  }

  [self removeAnimations];
  [self applyPropertiesWithoutAnimation:^{
    _strokeLayer.strokeStart = 0.0f;
    _strokeLayer.strokeEnd = 0.0f;
  }];
}

- (void)setCycleColors:(NSArray<UIColor *> *)cycleColors {
  if (cycleColors.count) {
    _cycleColors = [cycleColors copy];
  } else {
    _cycleColors = [MDCActivityIndicator defaultCycleColors];
  }

  if (self.cycleColors.count) {
    [self setStrokeColor:self.cycleColors[0]];
  }
}

- (void)updateStrokePath {
  CGFloat offsetRadius = _radius - _strokeLayer.lineWidth / 2.0f;
  UIBezierPath *strokePath = [UIBezierPath bezierPathWithArcCenter:_strokeLayer.position
                                                            radius:offsetRadius
                                                        startAngle:-1.0f * (CGFloat)M_PI_2
                                                          endAngle:3.0f * (CGFloat)M_PI_2
                                                         clockwise:YES];
  _strokeLayer.path = strokePath.CGPath;
  _trackLayer.path = strokePath.CGPath;

  _minStrokeDifference = _strokeLayer.lineWidth / ((CGFloat)M_PI * 2 * _radius);
}

- (void)updateStrokeColor {
  if (self.cycleColors.count > 0 && self.cycleColors.count > self.cycleColorsIndex) {
    [self setStrokeColor:self.cycleColors[self.cycleColorsIndex]];
  } else {
    NSAssert(NO, @"cycleColorsIndex is outside the bounds of cycleColors.");
    [self setStrokeColor:[[MDCActivityIndicator defaultCycleColors] firstObject]];
  }
}

- (void)addStrokeRotationCycle {
  if (_animationInProgress) {
    return;
  }

  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    [self strokeRotationCycleFinishedFromState:MDCActivityIndicatorStateIndeterminate];
  }];

  struct MDCActivityIndicatorMotionSpecIndeterminate timing = kMotionSpec.indeterminate;
  // These values may be equal if we've never received a progress. In this case we don't want our
  // duration to become zero.
  if (fabs(_lastProgress - _currentProgress) > CGFLOAT_EPSILON) {
    timing.strokeEnd.duration *= ABS(_lastProgress - _currentProgress);
  }

  [_animator animateWithTiming:timing.outerRotation
                       toLayer:_outerRotationLayer
                    withValues:@[@(kOuterRotationIncrement * _cycleCount),
                                 @(kOuterRotationIncrement * (_cycleCount + 1))]
                       keyPath:MDMKeyPathRotation];

  CGFloat startRotation = _cycleCount * (CGFloat)M_PI;
  CGFloat endRotation = startRotation + kCycleRotation * (CGFloat)M_PI;
  [_animator animateWithTiming:timing.innerRotation
                       toLayer:_strokeLayer
                    withValues:@[@(startRotation), @(endRotation)]
                       keyPath:MDMKeyPathRotation];

  [_animator animateWithTiming:timing.strokeStart
                       toLayer:_strokeLayer
                    withValues:@[@0, @(kStrokeLength)]
                       keyPath:MDMKeyPathStrokeStart];

  // Ensure the stroke never completely disappears on start by animating from non-zero start and
  // to a value slightly larger than the strokeStart's final value.
  [_animator animateWithTiming:timing.strokeEnd
                       toLayer:_strokeLayer
                    withValues:@[@(_minStrokeDifference), @(kStrokeLength + _minStrokeDifference)]
                       keyPath:MDMKeyPathStrokeEnd];

  [CATransaction commit];

  _animationInProgress = YES;
}

- (void)addTransitionToIndeterminateCycle {
  if (_animationInProgress) {
    return;
  }
  // Find the nearest cycle to transition through.
  NSInteger nearestCycle = 0;
  CGFloat nearestDistance = CGFLOAT_MAX;
  const CGFloat normalizedProgress = MAX(_lastProgress - _minStrokeDifference, 0.0f);
  for (NSInteger cycle = 0; cycle < kTotalDetentCount; cycle++) {
    const CGFloat currentRotation = [self normalizedRotationForCycle:cycle];
    if (currentRotation >= normalizedProgress) {
      if (nearestDistance >= (currentRotation - normalizedProgress)) {
        nearestDistance = currentRotation - normalizedProgress;
        nearestCycle = cycle;
      }
    }
  }

  if (nearestCycle == 0 && _lastProgress <= _minStrokeDifference) {
    // Special case for 0% progress.
    _cycleCount = nearestCycle;
    [self strokeRotationCycleFinishedFromState:MDCActivityIndicatorStateTransitionToIndeterminate];
    return;
  }

  _cycleCount = nearestCycle;

  CGFloat targetRotation = [self normalizedRotationForCycle:nearestCycle];
  if (targetRotation <= 0.001f) {
    targetRotation = 1.0f;
  }
  CGFloat normalizedDuration = 2 * (targetRotation + _currentProgress) / kSingleCycleRotation *
                               (CGFloat)kPointCycleDuration;
  CGFloat strokeEndTravelDistance = targetRotation - _currentProgress + _minStrokeDifference;
  CGFloat totalDistance = targetRotation + strokeEndTravelDistance;
  CGFloat strokeStartDuration =
      MAX(normalizedDuration * targetRotation / totalDistance,
          (CGFloat)kPointCycleMinimumVariableDuration);
  CGFloat strokeEndDuration = MAX(normalizedDuration * strokeEndTravelDistance / totalDistance,
                                  (CGFloat)kPointCycleMinimumVariableDuration);

  [CATransaction begin];
  {
    [CATransaction setCompletionBlock:^{
      [self
          strokeRotationCycleFinishedFromState:MDCActivityIndicatorStateTransitionToIndeterminate];
    }];
    [CATransaction setDisableActions:YES];

    struct MDCActivityIndicatorMotionSpecTransitionToIndeterminate timing =
        kMotionSpec.transitionToIndeterminate;

    _outerRotationLayer.transform = CATransform3DIdentity;
    _strokeLayer.transform = CATransform3DIdentity;

    timing.strokeStart.duration = strokeStartDuration;
    timing.strokeStart.delay = strokeEndDuration;
    [_animator animateWithTiming:timing.strokeStart
                         toLayer:_strokeLayer
                      withValues:@[@0, @(targetRotation)]
                         keyPath:MDMKeyPathStrokeStart];

    timing.strokeEnd.duration = strokeEndDuration;
    timing.strokeEnd.delay = 0;
    [_animator animateWithTiming:timing.strokeEnd
                         toLayer:_strokeLayer
                      withValues:@[@(_currentProgress), @(targetRotation + _minStrokeDifference)]
                         keyPath:MDMKeyPathStrokeEnd];
  }
  [CATransaction commit];

  _animationInProgress = YES;
}

- (void)addTransitionToDeterminateCycle {
  if (_animationInProgress) {
    return;
  }
  if (!_cycleCount) {
    // The animation period is complete: no need for transition.
    [_strokeLayer removeAllAnimations];
    [_outerRotationLayer removeAllAnimations];
    // Necessary for transition from indeterminate to determinate when cycle == 0.
    _currentProgress = 0.0f;
    _lastProgress = _currentProgress;
    [self strokeRotationCycleFinishedFromState:MDCActivityIndicatorStateTransitionToDeterminate];
  } else {
    _currentProgress = MAX(_progress, _minStrokeDifference);

    CGFloat rotationDelta = 1.0f - [self normalizedRotationForCycle:_cycleCount];

    // Change the duration relative to the distance in order to keep same relative speed.
    CGFloat duration = 2.0f * (rotationDelta + _currentProgress) / kSingleCycleRotation *
                       (CGFloat)kPointCycleDuration;
    duration = MAX(duration, (CGFloat)kPointCycleMinimumVariableDuration);

    [CATransaction begin];
    {
      [CATransaction setCompletionBlock:^{
        [self
            strokeRotationCycleFinishedFromState:MDCActivityIndicatorStateTransitionToDeterminate];
      }];
      [CATransaction setDisableActions:YES];
      [CATransaction mdm_setTimeScaleFactor:@(duration)];

      CGFloat startRotation = _cycleCount * (CGFloat)M_PI;
      CGFloat endRotation = startRotation + rotationDelta * 2.0f * (CGFloat)M_PI;
      [_animator animateWithTiming:kMotionSpec.transitionToDeterminate.innerRotation
                           toLayer:_strokeLayer
                        withValues:@[@(startRotation), @(endRotation)]
                           keyPath:MDMKeyPathRotation];

      _strokeLayer.strokeStart = 0;

      [_animator animateWithTiming:kMotionSpec.transitionToDeterminate.strokeEnd
                           toLayer:_strokeLayer
                        withValues:@[@(_minStrokeDifference), @(_currentProgress)]
                           keyPath:MDMKeyPathStrokeEnd];
    }
    [CATransaction commit];

    _animationInProgress = YES;
    _lastProgress = _currentProgress;
  }
}

- (void)addProgressAnimation {
  if (_animationInProgress) {
    return;
  }

  _currentProgress = MAX(_progress, _minStrokeDifference);

  [CATransaction begin];
  {
    [CATransaction setCompletionBlock:^{
      [self strokeRotationCycleFinishedFromState:MDCActivityIndicatorStateDeterminate];
    }];
    [CATransaction setDisableActions:YES];

    _outerRotationLayer.transform = CATransform3DIdentity;
    _strokeLayer.transform = CATransform3DIdentity;
    _strokeLayer.strokeStart = 0;

    [_animator animateWithTiming:kMotionSpec.progress.strokeEnd
                         toLayer:_strokeLayer
                      withValues:@[@(_lastProgress), @(_currentProgress)]
                         keyPath:MDMKeyPathStrokeEnd];
  }

  [CATransaction commit];

  _lastProgress = _currentProgress;
  _animationInProgress = YES;
}

- (void)strokeRotationCycleFinishedFromState:(MDCActivityIndicatorState)state {
  _animationInProgress = NO;

  if (!_animationsAdded) {
    return;
  }
  if (state == MDCActivityIndicatorStateIndeterminate) {
    if (self.cycleColors.count > 0) {
      self.cycleColorsIndex = (self.cycleColorsIndex + 1) % self.cycleColors.count;
      [self updateStrokeColor];
    }
    _cycleCount = (_cycleCount + 1) % kTotalDetentCount;
  }

  switch (_indicatorMode) {
    case MDCActivityIndicatorModeDeterminate:
      switch (state) {
        case MDCActivityIndicatorStateDeterminate:
        case MDCActivityIndicatorStateTransitionToDeterminate:
          [self addProgressAnimationIfRequired];
          break;
        case MDCActivityIndicatorStateIndeterminate:
        case MDCActivityIndicatorStateTransitionToIndeterminate:
          [self addTransitionToDeterminateCycle];
          break;
      }
      break;
    case MDCActivityIndicatorModeIndeterminate:
      switch (state) {
        case MDCActivityIndicatorStateDeterminate:
        case MDCActivityIndicatorStateTransitionToDeterminate:
          [self addTransitionToIndeterminateCycle];
          break;
        case MDCActivityIndicatorStateIndeterminate:
        case MDCActivityIndicatorStateTransitionToIndeterminate:
          [self addStrokeRotationCycle];
          break;
      }
      break;
  }
}

- (void)addProgressAnimationIfRequired {
  if (_indicatorMode == MDCActivityIndicatorModeDeterminate) {
    if (MAX(_progress, _minStrokeDifference) != _currentProgress) {
      // The values were changes in the while animating or animation is starting.
      [self addProgressAnimation];
    }
  }
}

/**
 Rotation that a given cycle has. Represented between 0.0f (cycle has no rotation) and 1.0f.
 */
- (CGFloat)normalizedRotationForCycle:(NSInteger)cycle {
  CGFloat cycleRotation = cycle * kSingleCycleRotation / 2.0f;
  return cycleRotation - ((NSInteger)cycleRotation);
}

- (void)animateOut {
  _animatingOut = YES;

  [CATransaction begin];

  [CATransaction setCompletionBlock:^{
    if (_animatingOut) {
      [self removeAnimations];
      if ([_delegate respondsToSelector:@selector(activityIndicatorAnimationDidFinish:)]) {
        [_delegate activityIndicatorAnimationDidFinish:self];
      }
    }
  }];
  [CATransaction setAnimationDuration:kAnimateOutDuration];

  _strokeLayer.lineWidth = 0;
  _trackLayer.lineWidth = 0;

  [CATransaction commit];
}

- (void)removeAnimations {
  _animationsAdded = NO;
  _animatingOut = NO;
  [_strokeLayer removeAllAnimations];
  [_outerRotationLayer removeAllAnimations];

  // Reset current and latest progress, to ensure addProgressAnimationIfRequired adds a progress animation
  // when returning from hidden.
  _currentProgress = 0;
  _lastProgress = 0;

  // Reset cycle count to 0 rather than cycleStart to reflect default starting position (top).
  _cycleCount = 0;
  // However _animationInProgress represents the CATransaction that hasn't finished, so we leave it
  // alone here.
}

+ (CGFloat)defaultHeight {
  return kSpinnerRadius * 2.f;
}

+ (NSArray<UIColor *> *)defaultCycleColors {
  static NSArray<UIColor *> *s_defaultCycleColors;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    s_defaultCycleColors =
    @[ MDCPalette.bluePalette.tint500,
       MDCPalette.redPalette.tint500,
       MDCPalette.yellowPalette.tint500,
       MDCPalette.greenPalette.tint500 ];
  });
  return s_defaultCycleColors;
}

- (void)applyPropertiesWithoutAnimation:(void (^)(void))setPropBlock {
  [CATransaction begin];

  // Disable implicit CALayer animations
  [CATransaction setDisableActions:YES];
  setPropBlock();

  [CATransaction commit];
}

#pragma mark - Resource Bundle

+ (NSBundle *)bundle {
  static NSBundle *bundle = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    bundle = [NSBundle bundleWithPath:[self bundlePathWithName:kBundle]];
  });

  return bundle;
}

+ (NSString *)bundlePathWithName:(NSString *)bundleName {
  // In iOS 8+, we could be included by way of a dynamic framework, and our resource bundles may
  // not be in the main .app bundle, but rather in a nested framework, so figure out where we live
  // and use that as the search location.
  NSBundle *bundle = [NSBundle bundleForClass:[MDCActivityIndicator class]];
  NSString *resourcePath = [(nil == bundle ? [NSBundle mainBundle] : bundle)resourcePath];
  return [resourcePath stringByAppendingPathComponent:bundleName];
}

#pragma mark - Accessibility

- (BOOL)isAccessibilityElement {
  return YES;
}

- (NSString *)accessibilityLabel {

  if (self.isAnimating) {
    if (self.indicatorMode == MDCActivityIndicatorModeIndeterminate) {
      NSString *key =
      kMaterialActivityIndicatorStringTable[kStr_MaterialActivityIndicatorInProgressAccessibilityLabel];
      return NSLocalizedStringFromTableInBundle(key,
                                                kMaterialActivityIndicatorStringsTableName,
                                                [[self class] bundle],
                                                @"In Progress");
    } else {
      NSUInteger percentage = (int)(self.progress * 100);
      NSString *key =
      kMaterialActivityIndicatorStringTable[kStr_MaterialActivityIndicatorProgressCompletedAccessibilityLabel];
      NSString *localizedString = NSLocalizedStringFromTableInBundle(key,
                                                kMaterialActivityIndicatorStringsTableName,
                                                [[self class] bundle],
                                                @"{percentage} Percent Complete");
      return [NSString localizedStringWithFormat:localizedString, percentage];
    }
  } else {
    NSString *key =
        kMaterialActivityIndicatorStringTable[kStr_MaterialActivityIndicatorProgressHaltedAccessibilityLabel];
    return NSLocalizedStringFromTableInBundle(key,
                                              kMaterialActivityIndicatorStringsTableName,
                                              [[self class] bundle],
                                              @"Progress Halted");
  }
}

- (UIAccessibilityTraits)accessibilityTraits {
  return UIAccessibilityTraitUpdatesFrequently;
}

- (NSString *)accessibilityValue {
  if (self.isAnimating) {
    return [NSNumberFormatter localizedStringFromNumber:@1 numberStyle:NSNumberFormatterNoStyle];
  } else {
    return [NSNumberFormatter localizedStringFromNumber:@0 numberStyle:NSNumberFormatterNoStyle];
  }
}

@end
