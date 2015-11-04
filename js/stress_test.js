var CommandWS = require("CommandWS.js");

var count = 0, sum = 0;

function StressTest(url, cb) {
	this.cws = new CommandWS(url);
	this.cws.on("open", cb.bind(this));
	this.cws.on("error", console.error.bind(console));
}

StressTest.prototype = {
	stress1:	function(bla, ble) {
		var date = Date.now();
		var sleep = parseInt(Math.random() * 5);
		return this.cws.cmd.stress1({
			date:		date,
			sleep_for:	sleep,
			bla:		bla,
			ble:		ble
		}, function(data) {
			if(data.error)
				throw data.error;
			count++;
			sum += Date.now() - (date + (sleep * 1000));
			document.querySelector("div#time").innerHTML = parseInt(sum / count) + " mills";
		});
	},
	run:		function(time) {
		time = time || 0;
		return setInterval(function() {
			this.stress1(Math.random() + "", Math.random() + "");
		}.bind(this), time);
	},
	stop:		function(id) {
		clearInterval(id);
	}
};

(function() {
	new StressTest("/ws", function() {
		//for(var i = 0; i < 10; i++) {
			var id = this.run();
			//setTimeout(this.prototype.stop.bind(this, id), 1000 * 10);
		//}
	});
})();
