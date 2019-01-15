/*global cordova,window,console*/
/**
 * A RTMP Live Player plugin for Cordova
 * 
 * Developed by John Weaver for Varsity Software
 */

var RTMPLivePlayer = function() {

};

RTMPLivePlayer.prototype.start = function(success, fail, options) {
	if (!options) {
		options = {};
	}

    return cordova.exec(success, fail, "RTMPLivePlayer", "start", [options]);
};

window.rtmpLivePlayer = new RTMPLivePlayer();
