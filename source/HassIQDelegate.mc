using Toybox.WatchUi;
using Toybox.Timer;

class HassIQMenuDelegate extends WatchUi.MenuInputDelegate {
	var parent;
	static var symbols=[:s0,:s1,:s2,:s3,:s4,:s5,:s6,:s7,:s8,:s9,:s10,:s11,:s12,:s13,:s14,:s15,:s16];

	function initialize(parent) {
		self.parent = parent;
		MenuInputDelegate.initialize();
	}

	function onMenuItem(item) {
		var size = symbols.size();
		for (var i=0; i<size; ++i) {
			if (symbols[i] == item) {
				parent.state.selected = parent.state.entities[i];
				parent.timer = new Timer.Timer();
				parent.timer.start(parent.method(:toggleSelected), 50, false);
				break;
			}
		}
	}
}

class HassIQProgressBarDelegate extends WatchUi.BehaviorDelegate {
	var parent;

	function initialize(parent) {
		self.parent = parent;
		WatchUi.BehaviorDelegate.initialize();
	}

	function onBack() {
		parent.progressBar = null;
		WatchUi.requestUpdate();
	}
}

class HassIQDelegate extends WatchUi.BehaviorDelegate {
	var state;
	var timer;
	var progressBar;
	var progressTimer;

	function initialize(state) {
		self.state = state;
		WatchUi.BehaviorDelegate.initialize();
	}

	function onMenu() {
		var menu = new WatchUi.Menu();
		menu.setTitle("Trigger");
		var size = (state.entities != null ? state.entities.size() : 0);
		if (HassIQMenuDelegate.symbols.size() < size) { size = HassIQMenuDelegate.symbols.size(); }
		if (size > 0) {
			for (var i=0; i<size; ++i) {
				var entity = state.entities[i];
				var title = entity[:name] ? entity[:name] : entity[:entity_id];
				menu.addItem(title, HassIQMenuDelegate.symbols[i]);
			}

			WatchUi.pushView(menu, new HassIQMenuDelegate(self), WatchUi.SLIDE_UP);
		}
		return true;
	}

	function onSelect() {
		onMenu();
	}

	function toggleSelected() {
		timer = null;

		var size = (state.entities != null ? state.entities.size() : 0);
		for (var i=0; i<size; ++i) {
			if (state.selected == state.entities[i]) {
				callEntityService(state.entities[i]);
				break;
			}
		}
	}

	function callEntityService(entity) {
		var domain = state.getEntityDomain(entity);
		if (domain.equals("group")) {
			state.setGroup(entity[:entity_id]);
			state.update(method(:onStateUpdated));
			return;
		}

		var service = null;
		if (domain.equals("automation")) {
			service = "trigger";
		} else if (domain.equals("script")) {
			service = state.getEntityId(entity);			
		} else if (domain.equals("scene")) {
			service = "turn_on";
		} else {
			domain = "homeassistant";
			service = "toggle";
		}

		progressBar = new WatchUi.ProgressBar("Triggering", null);
		WatchUi.pushView(progressBar, new HassIQProgressBarDelegate(self), WatchUi.SLIDE_DOWN);

		progressTimer = new Timer.Timer();
		progressTimer.start(method(:onTimer), 500, false);

		state.callService(domain, service, entity, method(:onServiceCalled));
	}

	function onStateUpdated(state) {
		WatchUi.requestUpdate();
	}

	// Combining the Timer & Service callbacks here let us avoid a CIQ crash that happens when we
	//  popView very shortly after we pushView.  This way we make sure enough time has lapsed before we popView.
	function onTimer() {
		if (progressTimer != null) {
			progressTimer = null;
			if (progressBar == null) {
				WatchUi.popView(WatchUi.SLIDE_UP);
				WatchUi.requestUpdate();
			}
		}
	}

	function onServiceCalled(state) {
		if (progressBar != null) {
			progressBar = null;
			if (progressTimer == null) {
				WatchUi.popView(WatchUi.SLIDE_UP);
				WatchUi.requestUpdate();
			}
		}
	}
}
