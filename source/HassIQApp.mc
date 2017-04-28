using Toybox.Application as App;

class HassIQApp extends App.AppBase {
	var state = new HassIQState();
	var view;
	var delegate;
	var host = "home:8123";

	function initialize() {
		AppBase.initialize();
	}

	function onStart(state) {
		self.state.load(getProperty("state"));
		onSettingsChanged();
	}

	// onStop() is called when your application is exiting
	function onStop(state) {
		setProperty("state", self.state.save());
	}

	function onSettingsChanged() {
		state.setHost(host ? host : getProperty("host"));
	}

	function getInitialView() {
		view = new HassIQView(state);
		delegate = new HassIQDelegate(state);
		
		onSettingsChanged();
		
		return [ view, delegate ];
	}
}
