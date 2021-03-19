#!/bin/sh
set -ex
if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then     # on pull requests
    echo "Build on PR"
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"BridgeAppExample"
elif [[ -z "$TRAVIS_TAG" && "$TRAVIS_BRANCH" == "main" ]]; then  # non-tag commits to main branch
    echo "Build on merge to main"
#    bundle exec fastlane ci_archive scheme:"BridgeAppExample" export_method:"app-store" project:"BridgeApp/BridgeApp.xcodeproj"
elif [[ -z "$TRAVIS_TAG" && "$TRAVIS_BRANCH" =~ ^stable-.* ]]; then # non-tag commits to stable branches
    echo "Build on stable branch"
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"BridgeAppExample"
    bundle exec fastlane bump_framework project:"BridgeApp/BridgeApp.xcodeproj" scheme:"BridgeApp (iOS)" framework:"BridgeApp"
#    bundle exec fastlane beta scheme:"BridgeAppExample" export_method:"app-store" project:"BridgeApp/BridgeApp.xcodeproj"
fi
exit $?
