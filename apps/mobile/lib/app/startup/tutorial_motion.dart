import 'dart:math' as math;

/// Page entry waits for meaningful painted content, then the hold and fade.
enum TutorialRevealPhase { entering, unobscured, fading, ready }

const tutorialPageHold = Duration(milliseconds: 600);
const tutorialSpotlightFade = Duration(milliseconds: 380);
const tutorialFocusFade = Duration(milliseconds: 180);
const tutorialPressDuration = Duration(milliseconds: 220);
const tutorialTravelDuration = Duration(milliseconds: 300);
const tutorialBrowseHold = Duration(seconds: 1);
const tutorialCoverWait = Duration(milliseconds: 600);

Duration tutorialBrowseScrollDuration(double distance) => Duration(
  milliseconds: (distance.abs() / 700 * 1000).round().clamp(300, 1100),
);
const tutorialScrollPixelsPerSecond = 500.0;

/// Linear motion keeps even exceptionally long descriptions below the cap.
Duration tutorialScrollDuration(double distance) => Duration(
  milliseconds: math.max(
    1,
    (distance.abs() / tutorialScrollPixelsPerSecond * 1000).ceil(),
  ),
);
