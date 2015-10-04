var Command = require("./Command.js");
const util = require('util');
const EventEmitter = require('events');

module.exports = CommandWS;
function CommandWS(path, via) {
	EventEmitter.call(this);
	if(via == null) {
		via = window.WebSocket != undefined ? "ws" : "lp";
	}
	this.via = via;
	this.cmd = {};
	this._path = path;
	this._init();
}

util.inherits(CommandWS, EventEmitter);

CommandWS.prototype.__defineGetter__("url", function() {
	if(this.via == "ws")
		return "ws://" + location.host + "/ws";
	else if(this.via == "lp")
		return "/ws";
	else
		throw "Invalid value for 'via': " + this.via;
});

CommandWS.prototype._lp		= null;

CommandWS.prototype._index	= 0;

CommandWS.prototype._init	= function() {
	if(this.via == "ws") {
		this._ws		= new WebSocket(this.url);
		this._ws.onmessage	= this._onMessage.bind(this);
		this._ws.onclose	= this._init.bind(this);
		this._ws.onopen		= this._onOpen.bind(this);
		this._ws.onerror	= this.emit.bind(this, "error");
	} else {
		this._xhr = new XMLHttpRequest();
		this._xhr.open("GET", this.url, true);
		this._xhr.onreadystatechange = this._onReadyStateChange.bind(this);
		this._xhr.send();
	}
};

CommandWS.prototype._onOpen	= function() {
	this.once("list_commands", this._onListCommands.bind(this));
	Command.sendCMD(this, "list_commands", null, this._lp, this.url);
};

CommandWS.prototype._onMessage	= function(evt) {
	this._parseAndEmitCmd(evt.data);
};

CommandWS.prototype._parseAndEmitCmd	= function(data) {
	try{
		var msg = JSON.parse(data);
	} catch(e) {
		console.error("ERROR:", e);
	}
	var cmd = new Command(this, msg);
	this.emit(msg.cmd, cmd);
	this.emit("command", cmd);
};

CommandWS.prototype._onReadyStateChange	= function() {
	if(this._xhr.readyState == 3) {
		if(this._lp == null) {
			var match = this._xhr.responseText.match(/lp\((\w{40})\)\[(.+?)\]/);
			this._lp	= match[1];
			this._delim	= match[2];
			this._index	= this._xhr.responseText.length;
			setTimeout(this._onOpen.bind(this));
		} else {
			var i = this._xhr.responseText.lastIndexOf(this._delim);
			if (i > this._index) {
				var newChunk = this._xhr.responseText.substr(this._index, (i - this._index));
				this._index = i + this._delim.length;
				this._parseAndEmitCmd(newChunk);
			}
		}
	}
};

CommandWS.prototype._onListCommands	= function(command) {
	Object.keys(command.msg.data).forEach(function(cmd) {
		var sendFunc = command.msg.data[cmd].type == "SUBSCRIBE" ? "subscribeCMD" : "sendCMD";
		var schema;
		if("schema" in command.msg.data[cmd]) {
			schema = command.msg.data[cmd].schema;
		}
		this.cmd[cmd] = function(data, cb) {
			if(schema) var result = tv4.validateMultiple(data, schema);
			if(result && !result.valid) {
				return cb({error: tv4.error});
			}
			var trans_id = Command[sendFunc](this, cmd, data, this._lp, this.url);
			var func = function(response) {
				if((
						response.msg.type == "RESPONSE"
						|| response.msg.type == "EVENT"
						|| response.msg.type == "ERROR"
					) && response.msg.trans_id == trans_id) {
					cb(response);
					if(response.msg.type != "EVENT")
						this.removeListener(cmd, func);
				}
			};
			this.on(cmd, func);
			return trans_id;
		}.bind(this);
	}.bind(this))
	this.emit("open");
};
