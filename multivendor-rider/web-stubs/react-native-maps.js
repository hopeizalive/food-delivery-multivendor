// Demo-only web stub. react-native-maps has no web implementation and its
// native Fabric components fail to even bundle for the web platform (Metro
// error: "Importing native-only module ... on web"). This file is swapped in
// for 'react-native-maps' ONLY on web builds via metro.config.js - native
// (iOS/Android) builds still use the real library, untouched.
//
// Renders a plain placeholder box instead of a real map. Good enough for the
// order-lifecycle demo, where the map on this one screen is not required to
// operate the actual accept/pickup/deliver actions.
import React, { forwardRef, useImperativeHandle } from "react";
import { StyleSheet, Text, View } from "react-native";

export const PROVIDER_DEFAULT = "default";
export const PROVIDER_GOOGLE = "google";

const MapView = forwardRef(({ style, children }, ref) => {
  useImperativeHandle(ref, () => ({
    animateToRegion: () => {},
    animateCamera: () => {},
    fitToCoordinates: () => {},
    fitToElements: () => {},
    getMapBoundaries: async () => ({
      northEast: { latitude: 0, longitude: 0 },
      southWest: { latitude: 0, longitude: 0 },
    }),
  }));

  return (
    <View style={[styles.map, style]}>
      <Text style={styles.label}>Map preview unavailable on web</Text>
      {children}
    </View>
  );
});
MapView.displayName = "MapView";

// Overlay components render nothing - there is no real map to place them on.
const NullComponent = () => null;

export const Marker = NullComponent;
export const Callout = NullComponent;
export const Polyline = NullComponent;
export const Polygon = NullComponent;
export const Circle = NullComponent;

const styles = StyleSheet.create({
  map: {
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#e2e8f0",
    minHeight: 120,
  },
  label: {
    color: "#475569",
    fontSize: 12,
  },
});

export default MapView;
