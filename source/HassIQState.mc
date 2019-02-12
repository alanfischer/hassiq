using Toybox.Communications as Comm;
using Toybox.Graphics;
using Toybox.WatchUi;

class HassIQState {
	var serviceCallback = null;
	var updateCallback = null;
	var status = 0;
	var entities = null;
	var selected = null;
	var host = null;
	var headers = null;
	var visibilityGroup = null;
	var password = null;
	var code = null;
	var token = null;
	var llat = null;
	var textsize = null;

	static var on = "on";
	static var off = "off";
	static var unknown = "unknown";

	function initialize() {
		setPassword(null);
	}

	function setHost(host) {
		var length = host.length();
		if (host.substring(length - 1, length).equals("/")) {
			self.host = host.substring(0, length - 1);
		} else {
			self.host = host;
		}
	}

	function setPassword(password) {
		self.password = password;
	}

	function setAuthCode(code) {
		self.code = code;
	}

	function setToken(token) {
		self.token = token;
	}

	function setLlat(llat) {
		self.llat = llat;
	}

	function setTextsize(textsize) {
		self.textsize = textsize;
	}
	
	function setGroup(group) {
		self.visibilityGroup = group;
	}

	function save() {
		if (entities == null) {
			return null;
		}

		var size = entities.size();		
		var stored = new [size];

		for (var i=0; i<size; ++i) {
			var entity = entities[i];
			stored[i] = { "entity_id" => entity[:entity_id], "name" => entity[:name], "state" => entity[:state] };
		}

		return stored;
	}

	function load(stored) {
		if (!(stored instanceof Array)) {
			return;
		}

		var size = stored.size();
		entities = new [size];

		for (var i=0; i<size; ++i) {
			var store = stored[i];
			entities[i] = { :entity_id => store["entity_id"], :name => store["name"], :state => store["state"] };
			if (entities[i][:state] != null) {
				updateEntityState(entities[i], entities[i][:state]);
			}
		}
	}

	function destroy() {
		self.updateCallback = null;
		self.serviceCallback = null;
	}

	function api() {
		return host + "/api";
	}

	function update(callback) {
		self.updateCallback = callback;

		if (password != null) {
			requestUpdate();
		} else if (code != null) {
			requestToken();
		} else {
			requestOAuth();
		}

		return true;
	}

	function requestOAuth() {
		Comm.registerForOAuthMessages(method(:onOAuthMessage));

		Comm.makeOAuthRequest(
			host + "/auth/authorize",
			{ "redirect_uri" => "https://www.hass-iq.net/auth", "client_id" => "https://www.hass-iq.net", "response_type" => "code" },
			"https://www.hass-iq.net",
			Comm.OAUTH_RESULT_TYPE_URL,
			{ "code" => "code", "error" => "error" }
		);
	}

	function onOAuthMessage(message) {
		if (message.data != null) {
			System.println("oauth data:" + message.data);

			var code = message.data["code"];
			var error = message.data["error"];

			setAuthCode(code);

			requestToken();
		} else {
			// return an error
		}
	}

	function requestToken() {
		System.println("Requesting token");

		if (Comm has :makeWebRequest) {
			Comm.makeWebRequest(host + "/auth/token",
				{
					"grant_type" => "authorization_code",
					"code" => code,
					"client_id" => "https://www.hass-iq.net"
				}, {
					:method => Comm.HTTP_REQUEST_METHOD_POST,
					:headers => { "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED },
				},
				method(:onTokenReceive) );
		} else {
			Comm.makeJsonRequest(host + "/auth/token",
				{
					"grant_type" => "authorization_code",
					"code" => code,
					"client_id" => "https://www.hass-iq.net"
				}, {
					:method => Comm.HTTP_REQUEST_METHOD_POST,
					:headers => { "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED },
				},
				method(:onTokenReceive) );
		}
	}

	function onTokenReceive(responseCode, data) {
		System.println("onTokenReceive:" + responseCode);
		self.status = responseCode;
		if (responseCode == 200) {
			log("Received token:" + data);

			setToken(data["access_token"]);
			requestUpdate();
		}
	}

	function requestUpdate() {
		System.println("Requesting update");

		if (llat != null) {
			headers = {
				"Content-Type" => Comm.REQUEST_CONTENT_TYPE_JSON, "Authorization" => "Bearer " + llat
			};
		} else if (password != null) {
			headers = {
				"Content-Type" => Comm.REQUEST_CONTENT_TYPE_JSON, "x-ha-access" => password
			};
		} else if (token != null) {
			headers = {
				"Content-Type" => Comm.REQUEST_CONTENT_TYPE_JSON, "Authorization" => "Bearer " + token
			};
		} else {
			headers = {
				"Content-Type" => Comm.REQUEST_CONTENT_TYPE_JSON
			};
		}

		if (Comm has :makeWebRequest) {
			Comm.makeWebRequest(api() + "/states/" + visibilityGroup, null,
				{ :method => Comm.HTTP_REQUEST_METHOD_GET, :headers => headers },
				method(:onUpdateReceive) );
		} else {
			Comm.makeJsonRequest(api() + "/states/" + visibilityGroup, null,
				{ :method => Comm.HTTP_REQUEST_METHOD_GET, :headers => headers },
				method(:onUpdateReceive) );
		}
	}

	function onUpdateReceive(responseCode, data) {
		self.status = responseCode;
		if (responseCode == 200) {
			log("Received data:" + data);

			var selected_id = self.selected != null ? self.selected[:entity_id] : null;
			self.selected = null;

			self.entities = buildEntities(data, entities);

			var size = entities.size();
			for (var i=0; i<size; ++i) {
				var entity = entities[i];

				if (selected_id != null && selected_id.equals(entity[:entity_id])) {
					self.selected = entity;
					break;
				}
			}

			if (size > 0) {
				singleUpdate(entities[0]);
			}
		} else {
			log("Failed to load\nError: " + responseCode.toString());
		}

		if (self.updateCallback != null) {
			self.updateCallback.invoke(self);
		}
	}

	function singleUpdate(entity) {
		log("Fetching:"+entity[:entity_id]);

		if (Comm has :makeWebRequest) {
			Comm.makeWebRequest(api() + "/states/" + entity[:entity_id], null,
				{ :method => Comm.HTTP_REQUEST_METHOD_GET, :headers => headers },
				method(:onSingleUpdateReceive) );
		} else {
			Comm.makeJsonRequest(api() + "/states/" + entity[:entity_id], null,
				{ :method => Comm.HTTP_REQUEST_METHOD_GET, :headers => headers },
				method(:onSingleUpdateReceive) );
		}
	}

	function onSingleUpdateReceive(responseCode, data) {
		if (responseCode == 200) {
			log("Received data:"+data);

			var entity = buildEntity(data, entities);
			if (entity == null) {
				return;
			}

			var size = entities.size();
			for (var i=0; i<size-1; ++i) {
				if (entity[:entity_id].equals(entities[i][:entity_id])) {
					singleUpdate(entities[i+1]);
				}
			}
		} else {
			log("Failed to load\nError: " + responseCode.toString());
		}

		if (self.updateCallback != null) {
			self.updateCallback.invoke(self);
		}
	}

	function callService(domain, service, entity, callback) {
		if(self.serviceCallback != null) {
			return false;
		}

		self.serviceCallback = callback;

		var data = {};
		if (domain != "script") {
			data = { "entity_id" => entity[:entity_id] };
		}

		if (Comm has :makeWebRequest) {
			Comm.makeWebRequest(api() + "/services/" + domain + "/" + service, data,
				{ :method => Comm.HTTP_REQUEST_METHOD_POST, :headers => headers },
				method(:onServiceReceive) );
		} else {
			Comm.makeJsonRequest(api() + "/services/" + domain + "/" + service, data,
				{ :method => Comm.HTTP_REQUEST_METHOD_POST, :headers => headers },
				method(:onServiceReceive) );
		}

		return true;
	}

	function onServiceReceive(responseCode, data) {
		if (responseCode == 200) {
			log("Received data:"+data);

			var size = data.size();
			for (var i=0; i<size; ++i) {
				buildEntity(data[i], entities);
			}
		} else {
			log("Failed to load\nError: " + responseCode.toString());
		}

		if (self.serviceCallback != null) {
			self.serviceCallback.invoke(self);
			self.serviceCallback = null;
		}
	}

	function updateEntityState(entity, state) {
		var domain = getEntityDomain(entity);

		if (state == null) {
			state = entity[:state] != null ? entity[:state] : unknown;
		}
		var drawable = null;
		if (domain.equals("sun")) {
			if (state.equals("above_horizon") ) {
				drawable = new WatchUi.Bitmap({:rezId=>Rez.Drawables.sun});
			} else {
				drawable = new WatchUi.Bitmap({:rezId=>Rez.Drawables.moon});
			}
			entity[:drawable] = drawable;
		} else {
			if (state.equals(on)) {
				state = on;
			} else if(state.equals(off)) {
				state = off;
			} else if(state.equals(unknown)) {
				state = unknown;
			}

			var title = entity[:name] ? entity[:name] : entity[:entity_id];
			var color = Graphics.COLOR_WHITE;
			var font = null;
			
			if (textsize == 0) {
			    font = Graphics.FONT_XTINY;
			} else {
			    font = Graphics.FONT_TINY;
			}

			if (state.length() == 0 || state.equals(off) || state.equals(unknown)) {
				color = Graphics.COLOR_DK_GRAY ;
			} else if (state.equals(on)) {
				color = Graphics.COLOR_WHITE;
			} else {
				title = title + ": " + state;
				color = Graphics.COLOR_WHITE;
			}

			entity[:title] = title;
			if (entity[:drawable]) {
				entity[:drawable].setText(title);
				entity[:drawable].setColor(color);
				entity[:drawable].setFont(font);
			} else {
				drawable = new WatchUi.Text({:text=>title, :font=>textsize, :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>0, :color=>color});
				entity[:drawable] = drawable;
			}
		}

		entity[:state] = state;
	}

	function buildEntity(item, previous) {
		var entity_id = item["entity_id"];
		var state = item["state"];
		var attributes = item["attributes"];
		var name = null;
		var hid = false;
		if (attributes != null) {
			name = attributes["friendly_name"];
			hid = attributes["hidden"];
			if (hid) {
				var view = attributes["view"];
				if (view != null && view == true) {
					hid = false;
				}
			}
		}

		if (hid == true) {
			return null;
		}

		var entity = null;
		if (previous != null) {
			for (var j=0; j<previous.size(); ++j) {
				if (previous[j][:entity_id].equals(entity_id)) {
					entity = previous[j];
					break;
				}
			}
		}
		if (entity == null) { entity = {:entity_id=>entity_id, :name=>name}; }
		else if (name != null) { entity[:name] = name; }

		updateEntityState(entity, state);

		return entity;
	}

	function buildEntities(data, previous) {
		var size = 0;
		var entities;
		if (data instanceof Array) {
			var entities_size = data.size();
			entities = new [entities_size];
			for (var i=0; i<entities_size; ++i) {
				var entity = buildEntity(data[i], previous);

				if (entity == null) {
					continue;
				}

				entities[size] = entity;
				size++;
			}
		} else {
			var entities_list = data["attributes"]["entity_id"];
			var entities_size = entities_list.size();
			entities = new [entities_size];
			for (var i=0; i<entities_size; ++i) {
				var entity = buildEntity({"entity_id" => entities_list[i]}, previous);

				if (entity == null) {
					continue;
				}

				entities[size] = entity;
				size++;
			}
		}

		var sorted = new [size];
		var s = 0;
		for (var p=0; p<2; ++p) {
			for (var i=0; i<size; ++i) {
				var entity = entities[i];
				var domain = getEntityDomain(entity);
				if (domain.equals("sun")) {
					if (p == 0) {
						sorted[s] = entity;
						s++;
					}
				} else {
					if (p == 1) {
						sorted[s] = entity;
						s++;
					}
				}
			}
		}

		return sorted;
	}

	function getEntityDomain(entity) {
		var entity_id = entity[:entity_id] ? entity[:entity_id] : entity["entity_id"];
		return split(entity_id, ".")[0];
	}

	function getEntityId(entity) {
		var entity_id = entity[:entity_id] ? entity[:entity_id] : entity["entity_id"];
		return split(entity_id, ".")[1];
	}

	function split(s, sep) {
		var tokens = [];

		var found = s.find(sep);
		while (found != null) {
			var token = s.substring(0, found);
			tokens.add(token);
			s = s.substring(found + sep.length(), s.length());
			found = s.find(sep);
		}

		tokens.add(s);

		return tokens;
	}

	function inArray(a, item) {
		var size = a.size();
		for (var i=0; i<size; ++i) {
			if (a[i].equals(item)) {
				return true;
			}
		}
		return false;
	}

	function log(message) {
		System.println(message);
	}

	(:test)
	function assert(condition) { if(!condition) { oh_no(); }}
	(:test)
	function test_buildEntities(logger) {
		var data = [
			{
				"attributes" => {
					"hidden" => true,
					"friendly_name" => "item1"
				},
				"entity_id" => "test.item1"
			},
			{
				"attributes" => {
					"friendly_name" => "item2"
				},
				"entity_id" => "test.item2"
			}
		];

		var entities = buildEntities(data, null);
		assert(entities.size() == 1);
		assert(getEntityDomain(entities[0]).equals("test"));
	}
}
