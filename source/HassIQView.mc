using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

class HassIQView extends Ui.View {
	var state;

	function initialize(state) {
		self.state = state;

		View.initialize();
	}

	function onLayout(dc) {
		onStateUpdated(state);

		self.state.update(method(:onStateUpdated));
	}

	function onStateUpdated(state) {
		Ui.requestUpdate();
   	}

	function onUpdate(dc) {
		// System.println("onUpdate");

		if (state.entities) {
			var size = state.entities.size();
			var layout = new [size];
			var l = 0;
			var height = dc.getFontHeight(Gfx.FONT_TINY);
			for(var i=0; i<size; ++i) {
				var entity = state.entities[i];
				var drawable = entity[:drawable];

				if (drawable == null) { continue; }

				if (true /*Show all*/) {
					drawable.setLocation(Ui.LAYOUT_HALIGN_CENTER, l * height);
					layout[l] = drawable;
					l++;
				}
				else {
					drawable.setLocation(Ui.LAYOUT_HALIGN_CENTER, Ui.LAYOUT_VALIGN_START);
				}
			}
   			setLayout(layout.slice(0,l));
		} else {
			setLayout(Rez.Layouts.MainLayout(dc));
		}

		View.onUpdate(dc);

		if (state.selected != null) {
			var drawable = state.selected[:drawable];
			var x = (dc.getWidth() - drawable.width)/2;
   			var y = drawable.locY;
			dc.drawRectangle(x, y, drawable.width, drawable.height);
		}

		var color = Gfx.COLOR_YELLOW;		
		if(state.state == -1) {
			color = Gfx.COLOR_RED;
		}
		else if(state.state == 1) {
			color = Gfx.COLOR_GREEN;
		}
		dc.setColor(color, color);
		dc.fillRectangle(0, dc.getHeight() - 4, dc.getWidth(), 4);
	}
}
