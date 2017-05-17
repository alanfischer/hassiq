using Toybox.Communications as Comm;
using Toybox.WatchUi as Ui;

class HassIQMenuDelegate extends Ui.MenuInputDelegate {
	var parent;
	var visible;
	static var symbols=[:s0,:s1,:s2,:s3,:s4,:s5,:s6,:s7,:s8,:s9,:s10,:s11,:s12,:s13,:s14,:s15,:s16];

	function initialize(parent, visible) {
		self.parent = parent;
		self.visible = visible;
		MenuInputDelegate.initialize();
	}

	function onMenuItem(item) {
		for (var i=0; i<symbols.size(); ++i) {
			if (symbols[i] == item) {
				parent.state.selected = visible[i];
				parent.timer = new Timer.Timer();
				parent.timer.start(parent.method(:onSelect), 50, false);
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

	function getVisibleEntities() {
		var size = state.entities.size();
		var visible = new [size];
		var v = 0;
		for (var i=0; i<size; ++i) {
			var entity = state.entities[i];
			if (entity[:drawable]!=null && entity[:drawable].locY!=Ui.LAYOUT_VALIGN_START) {
				visible[v]=entity;
				v++;
			}
		}
		return visible.slice(0,v);
	}

	function onMenu() {
		var visible = getVisibleEntities();
		var size = visible.size();

		// Reorder visibles with selected as first
		for (var i=0; i<size; ++i) {
			if (state.selected == visible[i]) {
				var ordered = new [size];
				for (var j=0; j<size; ++j) {
					ordered[j] = visible[(i+j) % size];
				}
				visible = ordered;
				break;
			}
		}

		var menu = new Ui.Menu();
		menu.setTitle("Trigger");
		for (var i=0; i<size; ++i) {
			menu.addItem(visible[i][:name], HassIQMenuDelegate.symbols[i]);
		}

		Ui.pushView(menu, new HassIQMenuDelegate(self, visible), Ui.SLIDE_UP);
		return true;
	}

	function onSelect() {
		timer = null;

		var visible = getVisibleEntities();
		for (var i=0; i<visible.size(); ++i) {
			if (state.selected == visible[i]) {
				callEntityService(visible[i]);
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
