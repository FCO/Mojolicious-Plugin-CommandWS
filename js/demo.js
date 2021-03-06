var CommandWS = require("CommandWS.js");
var cmd = new CommandWS("/ws", location.hash == "#lp" ? "lp" : null);
cmd.on("command", function(data) {
	var div = document.createElement("DIV");
	div.innerHTML = JSON.stringify(data.msg);
	document.querySelector("div#responses").appendChild(div);
});
cmd.once("open", function() {
	var box = document.querySelector("div#cmd_box");
	Object.keys(this.cmd).sort().forEach(function(cmd) {
		var opt = document.createElement("OPTION");
		opt.text	= cmd;
		opt.value	= cmd;
		box.querySelector("select#cmd").appendChild(opt);
	});
	box.querySelector("input#send").addEventListener("click", function() {
		var sel		= box.querySelector("select#cmd");
		var command	= sel.options[sel.selectedIndex].text;
		var data	= box.querySelector("textarea#data").value;

		var response = document.createElement("TD");
		var jsonData, invalidJson = false;
		try {
			jsonData = JSON.parse(data);
		} catch(e){
			if(data != "") invalidJson = e.message;
		};
		var trans_id	= cmd.cmd[command](jsonData, function(resp) {
			if(resp.error)
				response.innerHTML = "<font color=red>" + JSON.stringify(resp.error) + "</font>";
			else
				response.innerHTML = JSON.stringify(resp.data);
		});

		var hist	= document.createElement("DIV");
		var tab		= document.createElement("TABLE");
		hist.appendChild(tab);

		var tr = document.createElement("TR");
		tab.appendChild(tr);

		var title = document.createElement("TD");
		title.innerHTML = "Command";
		tr.appendChild(title);

		var value = document.createElement("TD");
		if(invalidJson) {
			console.warn(invalidJson);
			data = "<font color=red>" + data + "</font>";
		}
		value.innerHTML = command + "(" + data + ")";
		tr.appendChild(value);

		var tr2 = document.createElement("TR");
		tab.appendChild(tr2);

		var title2 = document.createElement("TD");
		title2.innerHTML = "Response";
		tr2.appendChild(title2);

		tr2.appendChild(response);

		document.querySelector("div#history").appendChild(hist);
	});
});
