using Toybox.Communications as Comm;
using Toybox.WatchUi as Ui;

class HassIQMenuDelegate extends Ui.MenuInputDelegate {
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

class HassIQProgressBarDelegate extends Ui.BehaviorDelegate {
	var parent;

	function initialize(parent) {
		self.parent = parent;
		Ui.BehaviorDelegate.initialize();
	}

	function onBack() {
		parent.progressBar = null;
		Ui.requestUpdate();
	}
}

class HassIQDelegate extends Ui.BehaviorDelegate {
	var state;
	var timer;
	var progressBar;

	function initialize(state) {
		self.state = state;
		Ui.BehaviorDelegate.initialize();
	}

	function onMenu() {
		var menu = new Ui.Menu();
		menu.setTitle("Trigger");
		var size = (state.entities != null ? state.entities.size() : 0);
		if (HassIQMenuDelegate.symbols.size() < size) { size = HassIQMenuDelegate.symbols.size(); }
		for (var i=0; i<size; ++i) {
			menu.addItem(state.entities[i][:title], HassIQMenuDelegate.symbols[i]);
		}

		Ui.pushView(menu, new HassIQMenuDelegate(self), Ui.SLIDE_UP);
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
		var domain = null;
		var service = null;
		if (state.getEntityDomain(entity).equals("automation")) {
			domain = "automation";
			service = "trigger";
		}
		else {
			domain = "homeassistant";
			service = "toggle";
		}
		
		progressBar = new Ui.ProgressBar("Triggering", null);
		Ui.pushView(progressBar, new HassIQProgressBarDelegate(self), Ui.SLIDE_DOWN);
		state.callService(domain, service, entity, method(:onServiceCalled));
	}

	function onServiceCalled(state) {
		if (progressBar != null) {
			progressBar = null;
			try {
				Ui.popView(Ui.SLIDE_UP);
			} catch(ex) { }
		}
		Ui.requestUpdate();
	}
}
