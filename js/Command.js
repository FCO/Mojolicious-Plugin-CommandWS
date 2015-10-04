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

var crypto = require('crypto');

function Command(sock, msg, url) {
	this.sock	= sock;
	this.msg	= msg || {};
	this.url	= url;
	if(!("version" in this.msg))
		this.msg.version = 1;
	if("checksum" in msg && msg.checksum != this.generateChecksum()) {
		throw new Error("Invalid checksum");
	}
}

Command.counter = 0;

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
	// TODO: Fix data
	fields2check:	["cmd", "counter", "trans_id", "version", "type"],
	send:		function() {
		this.msg.counter = Command.counter++;
		if(!this.msg.type)
			this.msg.type = Command.flow.__init__;
		if(!this.msg.trans_id)
			this.msg.trans_id = this.createTransId();

		this.msg.checksum = this.generateChecksum();
		if(this.msg.lp == null)
			this.sock._ws.send(JSON.stringify(this.msg));
		else {
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
		var shasum = crypto.createHash('sha1');
		shasum.update([Command.counter, new Date(), Math.random()].join(" - "));
		return shasum.digest('hex');
	},
	generateChecksum: function() {
		var shasum = crypto.createHash('sha1');
		var seed = this.fields2check.map(function(field) {
			return this.msg[field]
		}.bind(this)).join("\n")
		console.log("seed", seed);
		shasum.update(seed);
		return shasum.digest('hex');
	}
};

module.exports = Command;
