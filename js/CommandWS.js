var Command = require("./Command.js");
const util = require('util');
const EventEmitter = require('events');
const tv4 = require("tv4");

module.exports = CommandWS;
function CommandWS(url, via) {
	EventEmitter.call(this);
	if(via == null) {
		via = window.WebSocket != undefined ? "ws" : "lp";
	}
	this.via = via;
	this.cmd = {};

	this._url = document.createElement("A");
	this._url.href = url;
	this._ssl = this._url.protocol == "ws:" || this._url.protocol == "https:";
	this._init();
}

util.inherits(CommandWS, EventEmitter);

CommandWS.prototype.__defineGetter__("_wsProto", function() {
	return "ws" + (this._ssl ? "s:" : ":");
});

CommandWS.prototype.__defineGetter__("_httpProto", function() {
	return "http" + (this._ssl ? "s:" : ":");
});

CommandWS.prototype.__defineGetter__("url", function() {
	var url = document.createElement("A");
	url.href = this._url.href;

	if(this.via == "ws")
		url.protocol = this._wsProto;
	else if(this.via == "lp")
		url.protocol = this._httpProto;
	else
		throw "Invalid value for 'via': " + this.via;
	return url.href;
});

CommandWS.prototype._lp		= null;

CommandWS.prototype._index	= 0;

CommandWS.prototype._init	= function() {
	this.cmd = {};
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
		console.error("DATA :", data);
	}
	var cmd = new Command(this, msg);
	this.emit(msg.cmd, cmd);
	this.emit(msg.cmd + " " + msg.trans_id, cmd);
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
				newChunk.split(this._delim).forEach(function(chunk) {
					this._parseAndEmitCmd(chunk);
				}.bind(this));
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
			if(schema) {
				schema = (schema instanceof Array ? schema : [schema]);
				for(var i = 0; i < schema.length; i++) {
					var sch = schema[i];
					var valid = tv4.validate(data, sch);
					console.log("result:", valid);
					if(!valid) {
						console.warn("local_validation fail:", tv4.error);
						return cb({error: tv4.error});
					}
				}
			}
			var trans_id = Command[sendFunc](this, cmd, data, this._lp, this.url);
			var func = function(response) {
				cb(response);
				if(response.msg.type != "EVENT")
					this.removeListener(cmd, func);
			};
			this.on(cmd + " " + trans_id, func);
			return trans_id;
		}.bind(this);
	}.bind(this))
	this.emit("open");
};

