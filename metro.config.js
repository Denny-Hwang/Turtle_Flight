const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

config.resolver.assetExts.push('glb', 'gltf', 'obj', 'mtl');
config.resolver.sourceExts.push('cjs', 'mjs');

module.exports = config;
