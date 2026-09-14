/* eslint-disable no-undef */
/* eslint-disable @typescript-eslint/no-require-imports */
// const { getDefaultConfig } = require("expo/metro-config");
const { withNativeWind } = require("nativewind/metro");
const { getSentryExpoConfig } = require("@sentry/react-native/metro");

// eslint-disable-next-line no-undef
// const config = getDefaultConfig(__dirname);
const config = getSentryExpoConfig(__dirname);

// config.resolver.disableHierarchicalLookup = true;

const finalConfig = withNativeWind(config, { input: "./global.css" });

// Demo-only: react-native-maps (and its directions helper) have no web
// implementation and fail to even bundle for web (Metro: "Importing
// native-only module ... on web"). Redirect them to plain placeholder
// components on web ONLY - native iOS/Android builds are untouched, they
// never hit this branch. See web-stubs/react-native-maps.js.
const previousResolveRequest = finalConfig.resolver.resolveRequest;
finalConfig.resolver.resolveRequest = (context, moduleName, platform) => {
  if (platform === "web") {
    if (moduleName === "react-native-maps" || moduleName.startsWith("react-native-maps/")) {
      return { type: "sourceFile", filePath: require.resolve("./web-stubs/react-native-maps.js") };
    }
    if (moduleName === "react-native-maps-directions") {
      return { type: "sourceFile", filePath: require.resolve("./web-stubs/react-native-maps-directions.js") };
    }
  }
  if (previousResolveRequest) {
    return previousResolveRequest(context, moduleName, platform);
  }
  return context.resolveRequest(context, moduleName, platform);
};

module.exports = finalConfig;
