{
  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      expose-animation-duration = 0.0;
      launchanim = false;
      magnification = false;
      mru-spaces = false;
      show-recents = false;
      tilesize = 32;
      # Hot corners (only corner actions, modifiers not supported by nix-darwin)
      wvous-tl-corner = 1;   # Top-left: Disabled
      wvous-tr-corner = 12;  # Top-right: Notification Center
      wvous-bl-corner = 1;   # Bottom-left: Disabled
      wvous-br-corner = 4;   # Bottom-right: Desktop
    };
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      QuitMenuItem = true;
      ShowStatusBar = true;
      ShowPathbar = true;
      FXDefaultSearchScope = "SCcf";
      FXPreferredViewStyle = "Nlsv";
      _FXSortFoldersFirst = true;
    };
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
      ActuationStrength = 0;
      FirstClickThreshold = 1;
      SecondClickThreshold = 1;
    };
    controlcenter = {
      BatteryShowPercentage = true;
      Sound = true;
      Bluetooth = true;
      FocusModes = true;
      NowPlaying = true;
      Display = false;
      AirDrop = false;
    };
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
    screencapture.location = "~/Desktop";
    NSGlobalDomain = {
      "com.apple.swipescrolldirection" = true;
      "_HIHideMenuBar" = true;
      "NSWindowShouldDragOnGesture" = true;
      "NSWindowResizeTime" = 0.0;
      "InitialKeyRepeat" = 15;
      "KeyRepeat" = 2;
      "AppleShowAllFiles" = true;
      "AppleInterfaceStyle" = "Dark";
      "com.apple.keyboard.fnState" = false;
      "AppleShowScrollBars" = "Always";
      "AppleEnableSwipeNavigateWithScrolls" = true;
      "com.apple.mouse.tapBehavior" = 1;
      
      # Keyboard text input settings
      "NSAutomaticCapitalizationEnabled" = false;
      "NSAutomaticSpellingCorrectionEnabled" = false;
      "NSAutomaticPeriodSubstitutionEnabled" = true;
      "NSAutomaticQuoteSubstitutionEnabled" = true;
      "NSAutomaticDashSubstitutionEnabled" = true;
      "ApplePressAndHoldEnabled" = false;
      
      # Window management
      "AppleWindowTabbingMode" = "always";
    };
    CustomUserPreferences = {
      # Caps Lock to Escape remapping
      "com.apple.HIToolbox" = {
        AppleCurrentKeyboardLayoutInputSourceID = "com.apple.keylayout.US";
        AppleSelectedInputSources = [
          {
            "InputSourceKind" = "Keyboard Layout";
            "KeyboardLayout ID" = 0;
            "KeyboardLayout Name" = "U.S.";
          }
        ];
      };
      "NSGlobalDomain" = {
        "com.apple.keyboard.modifiermapping.1452-567-0" = [
          {
            HIDKeyboardModifierMappingDst = 30064771113;
            HIDKeyboardModifierMappingSrc = 30064771129;
          }
        ];
      };
      "com.jetbrains.intellij" = { ApplePressAndHoldEnabled = false; };
      "com.jetbrains.intellij-EAP" = { ApplePressAndHoldEnabled = false; };
      "com.google.android.studio-EAP" = { ApplePressAndHoldEnabled = false; };
      "com.google.android.studio" = { ApplePressAndHoldEnabled = false; };
      "com.apple.AppleMultitouchTrackpad" = {
        TrackpadFourFingerHorizSwipeGesture = 2;
        TrackpadFourFingerVertSwipeGesture = 2;  # App Exposé (swipe down with four fingers)
        TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
        TrackpadFiveFingerPinchGesture = 2;
        TrackpadFourFingerPinchGesture = 2;
        TrackpadTwoFingerDoubleTapGesture = 1;
        TrackpadThreeFingerTapGesture = 0;
        TrackpadThreeFingerHorizSwipeGesture = 0;
        TrackpadThreeFingerVertSwipeGesture = 0;
        ForceSuppressed = false;
        # Enable trackpad for dragging
        Dragging = true;
        # Three finger drag style
        TrackpadThreeFingerDrag = true;
      };
      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
        TrackpadThreeFingerDrag = true;
        Clicking = true;
        TrackpadRightClick = true;
        ClickingStyle = 2;
        ActuationStrength = 0;
        ForceClick = true;
      };
      # System preferences - Formats
      "NSGlobalDomain" = {
        # Temperature: Celsius
        AppleTemperatureUnit = "Celsius";
        # Measurement system: Metric
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = true;
        # First day of week: Monday
        AppleFirstWeekday = { gregorian = 2; };
        # Date format: DD/MM/YYYY
        AppleICUDateFormatStrings = {
          "1" = "d/M/y";
          "2" = "d MMM y";
          "3" = "d MMMM y";
          "4" = "EEEE, d MMMM y";
        };
        # Number format: 1,234,567.89
        AppleICUNumberFormatDecimalSeparator = ".";
        AppleICUNumberFormatThousandsSeparator = ",";
      };
      "com.apple.menuextra.clock" = { Show24Hour = true; };
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = { 
          # Spotlight / Finder search
          "60" = { enabled = false; };  # Spotlight (one of the variants)
          "64" = { enabled = false; };  # Spotlight (other variant)  
          "65" = { enabled = false; };  # Show Finder search window (⌥⌘Space)
        };
      };
      "com.apple.dock" = {
        # Enable App Exposé gesture (swipe down with four fingers)  
        showAppExposeGestureEnabled = true;
      };
    };
  };
}