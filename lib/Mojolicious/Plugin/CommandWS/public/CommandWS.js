function CommandWS(url) {
	this.cmd = {};
	this._url = url;
	this._init();
}

CommandWS.prototype = {
	_init:	function() {
		this._listeners		= {};
		this._ws		= new WebSocket(this._url);
		this._ws.onmessage	= this._onMessage.bind(this);
		this._ws.onclose	= this._init.bind(this);
		this._ws.onopen		= this._onOpen.bind(this);
		this._ws.onerror	= this.emit.bind(this, "error");
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
		this.on("list_commands", this._onListCommands.bind(this));
		Command.sendCMD(this, "list_commands");
	},
	_onMessage:		function(evt) {
		var msg = JSON.parse(evt.data);
		this.emit(msg.cmd, new Command(this, msg));
	},
	_onListCommands:	function(command) {
		Object.keys(command.msg.data).forEach(function(cmd) {
			var sendFunc = command.msg.data[cmd].type == "SUBSCRIBE" ? "subscribeCMD" : "sendCMD";
			var schema;
			if("schema" in command.msg.data[cmd]) {
				schema = command.msg.data[cmd].schema;
			}
			this.cmd[cmd] = function(data, cb) {
				console.log("SCHEMA: ", schema);
				console.log("DATA: ", data);
				if(schema) var result = tv4.validateMultiple(data, schema);
				console.log(result);
				if(result && !result.valid) {
					console.log("deu ruim");
					return cb({error: tv4.error});
				}
				var trans_id = Command[sendFunc](this, cmd, data);
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
// 	version		=> 1,
// 	counter		=> 2,
// 	cmd		=> "command_name",
//	type		=> "REQUEST",
// 	trans_id	=> "1234567890123456789012345678901234567890",
// 	data		=> {data},
//	checksum	=> "1234567890123456789012345678901234567890"
// }

function Command(sock, msg) {
	this.sock	= sock;
	this.msg	= msg || {};
}

Command.flow = {
	__init__:	"REQUEST",
	REQUEST:	"RESPONSE",
	RESPONSE:	"CONFIRM",
	__subs__:	"SUBSCRIBE",
	SUBSCRIBE:	"EVENT",
	EVENT:		"EVENT"
};

Command.subscribeCMD = function(sock, cmd, data) {
	var newCMD = new Command(sock, {cmd: cmd, data: data, type: Command.flow.__subs__});
	newCMD.send();
	return newCMD.msg.trans_id;
};

Command.sendCMD = function(sock, cmd, data) {
	var newCMD = new Command(sock, {cmd: cmd, data: data});
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
		console.log("send");
		if(!this.msg.type)
			this.msg.type = Command.flow.__init__;
		if(!this.msg.trans_id)
			this.msg.trans_id = this.createTransId();

		this.sock._ws.send(JSON.stringify(this.msg));
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





