using Toybox.Application as App;

class HassIQApp extends App.AppBase {
	var state = new HassIQState();
	var view;
	var delegate;
	var host = "http://hassbian.local:8123";
	var password = null;

	function initialize() {
		AppBase.initialize();
	}

	function onStart(state) {
		self.state.load(getProperty("state"));

		var selected = getProperty("selected");
		if (selected != null) {
			for (var i=0; i<self.state.entities.size(); ++i) {
				if (self.state.entities[i][:entity_id].equals(selected)) {
					self.state.selected = self.state.entities[i];
					break;
				}
			}
		}

		onSettingsChanged();
	}

	function onStop(state) {
		setProperty("state", self.state.save());

		var selected = null;
		if (self.state.selected != null) {
			selected = self.state.selected[:entity_id];
		}
		setProperty("selected", selected);
	}

	function onSettingsChanged() {
		var stateHost = getProperty("host");
		var statePassword = getProperty("password");

		if (stateHost == null || stateHost.length() == 0) {
			stateHost = host;
		}
		if (statePassword == null || statePassword.length() == 0) {
			statePassword = password;
		}

		state.setHost(stateHost);
		state.setPassword(statePassword);
	}

	function getInitialView() {
		delegate = new HassIQDelegate(state);
		view = new HassIQView(state);
		
		onSettingsChanged();

		return [view, delegate];
	}
}
