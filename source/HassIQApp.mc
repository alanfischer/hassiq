using Toybox.Application;

class HassIQApp extends Application.AppBase {
	var state = new HassIQState();
	var view;
	var delegate;

	function initialize() {
		AppBase.initialize();
	}

	function onStart(state) {
		onSettingsChanged();
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
	}

	function onStop(state) {
		setProperty("state", self.state.save());

		var selected = null;
		if (self.state.selected != null) {
			selected = self.state.selected[:entity_id];
		}
		setProperty("selected", selected);

		self.state.destroy();
	}

	function onSettingsChanged() {
		var host = getProperty("host");
		var password = getProperty("password");
		var group = getProperty("group");
		var llat = getProperty("llat");
		var textsize = getProperty("textsize");

		state.setHost(host);
		state.setPassword(password);
		state.setGroup(group);
		state.setLlat(llat);
		state.setTextsize(textsize);

		if (view != null) {
			view.requestUpdate();
		}
	}

	function getInitialView() {
		delegate = new HassIQDelegate(state);
		view = new HassIQView(state);

		return [view, delegate];
	}
}
