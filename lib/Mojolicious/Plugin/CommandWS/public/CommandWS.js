function CommandWS(path, via) {
	if(via == null) {
		via = window.WebSocket != undefined ? "ws" : "lp";
	}
	this.via = via;
	console.log(via);
	this.cmd = {};
	this._path = path;
	this._init();
}

CommandWS.prototype = {
	get url() {
		if(this.via == "ws")
			return "ws://" + location.host + "/ws";
		else if(this.via == "lp")
			return "/ws";
		else
			throw "Invalid value for 'via': " + this.via;
	},
	_lp:	null,
	_index:	0,
	_init:	function() {
		console.log("_init");
		this._listeners		= {};
		if(this.via == "ws") {
			this._ws		= new WebSocket(this.url);
			this._ws.onmessage	= this._onMessage.bind(this);
			this._ws.onclose	= this._init.bind(this);
			this._ws.onopen		= this._onOpen.bind(this);
			this._ws.onerror	= this.emit.bind(this, "error");
		} else {
			console.log("_init lp");
			this._xhr = new XMLHttpRequest();
			this._xhr.open("GET", this.url, true);
			this._xhr.onreadystatechange = this._onReadyStateChange.bind(this);
			this._xhr.send();
		}
	},
	on:	function(name, cb) {
		if(!(name in this._listeners))
			this._listeners[name] = [];
		this._listeners[name].push(cb);
		return this;
	},
	remove:	function(name, func) {
		if(name in this._listeners) {
			var index = this._listeners[name].indexOf(func);
			this._listeners[name].splice(index, 1);
		}
		return func;
	},
	emit:	function() {
		var args = Array.prototype.slice.call(arguments);
		var name = args.shift();
		args.unshift(this);
		if("on" + name in this) {
			setTimeout(Function.prototype.bind.apply(this["on" + name], args));
		}
		if(name in this._listeners) {
			this._listeners[name].forEach(function(cb) {
				console.log(args);
				setTimeout(Function.prototype.bind.apply(cb, args));
			}.bind(this));
		}
	},
	_onOpen:		function() {
					console.log("_onOpen");
		this.on("list_commands", this._onListCommands.bind(this));
		Command.sendCMD(this, "list_commands", null, this._lp, this.url);
	},
	_onMessage:		function(evt) {
		this._parseAndEmitCmd(evt.data);
	},
	_parseAndEmitCmd:	function(data) {
		var msg = JSON.parse(data);
		var cmd = new Command(this, msg);
		this.emit(msg.cmd, cmd);
		this.emit("command", cmd);
	},
	_onReadyStateChange: function() {
		if(this._xhr.readyState == 3) {
			console.log(this._xhr.responseText);
			if(this._lp == null) {
				var match = this._xhr.responseText.match(/lp\((\w{40})\)\[(.+?)\]/);
				console.log(match[1] + " => " + match[2]);
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
	},
	_onListCommands:	function(command) {
		Object.keys(command.msg.data).forEach(function(cmd) {
			var sendFunc = command.msg.data[cmd].type == "SUBSCRIBE" ? "subscribeCMD" : "sendCMD";
			var schema;
			if("schema" in command.msg.data[cmd]) {
				schema = command.msg.data[cmd].schema;
			}
			this.cmd[cmd] = function(data, cb) {
				console.log(cmd, data);
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
							this.remove(cmd, func);
					}
				};
				this.on(cmd, func);
				return trans_id;
			}.bind(this);
		}.bind(this))
		this.emit("open");
	}
};

// msg:
// {
// 	lp		=> "1234567890123456789012345678901234567890",
// 	version		=> 1,
// 	counter		=> 2,
// 	cmd		=> "command_name",
//	type		=> "REQUEST",
// 	trans_id	=> "1234567890123456789012345678901234567890",
// 	data		=> {data},
//	checksum	=> "1234567890123456789012345678901234567890"
// }

function Command(sock, msg, url) {
	this.sock	= sock;
	this.msg	= msg || {};
	this.url	= url;
}

Command.flow = {
	__init__:	"REQUEST",
	REQUEST:	"RESPONSE",
	RESPONSE:	"CONFIRM",
	__subs__:	"SUBSCRIBE",
	SUBSCRIBE:	"EVENT",
	EVENT:		"EVENT"
};

Command.subscribeCMD = function(sock, cmd, data, lp, url) {
	var newCMD = new Command(sock, {cmd: cmd, data: data, type: Command.flow.__subs__, lp: lp}, url);
	newCMD.send();
	return newCMD.msg.trans_id;
};

Command.sendCMD = function(sock, cmd, data, lp, url) {
	console.log("sendCMD", lp);
	var newCMD = new Command(sock, {cmd: cmd, data: data, lp: lp}, url);
	newCMD.send();
	return newCMD.msg.trans_id;
};

Command.prototype = {
	get error() {
		if(this.msg.type == "ERROR") return this.msg.data;
	},
	get data() {
		if(this.msg.type != "ERROR") return this.msg.data;
	},
	send:		function() {
		console.log("send", this.msg.lp);
		if(!this.msg.type)
			this.msg.type = Command.flow.__init__;
		if(!this.msg.trans_id)
			this.msg.trans_id = this.createTransId();

		if(this.msg.lp == null)
			this.sock._ws.send(JSON.stringify(this.msg));
		else {
			console.log("send: " + this.url);
			var xhr = new XMLHttpRequest();
			xhr.open("POST", this.url, true);
			xhr.setRequestHeader("Content-type", "application/json");
			xhr.send(JSON.stringify(this.msg));
		}
	},
	clone:		function() {
		return new Command(this.sock, this.msg);
	},
	reply:		function(data) {
		var reply = this.clone();
		reply.msg.type	= Command.flow[this.msg.type];
		reply.msg.data	= data;
		reply.send()
	},
	createTransId:	function() {
		return "1234567890123456789012345678901234567890";
	},
};





