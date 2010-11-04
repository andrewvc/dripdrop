$(function() {
  window.submitTraceForm = function () {
    var ip = $('#traceroute-ip').val();
    var msg = new DD.Message('ip_trace_req', {body: {ip: ip}});
    $.post('http://stringer.andrewvc.com:8082', msg.jsonEncoded(), function (msg) {
      console.log(msg);
    }); 
    return false;
  };
  
  var forceData = {};
  
  var ws = new DD.WebSocket('ws://stringer.andrewvc.com:2202');
  ws.onOpen(function () {
  }).onRecv(function (message) {
    if (message.name != 'ip_route') return;
    
    forceData[message.body.ip] = message.body.route;
  }).onClose(function () {
    
  }).onError(function () {

  });

  setInterval(function() {
    window.renderForce();
  }, 3000);
  
  
  var processForceData = function () {
    var oldforceData = {
      '127.0.0.1': ['192.168.2.1', '192.291.12.2', 'router.what.com'],
      '127.0.2.1': ['192.168.3.1', '192.291.12.2', 'router.what.com'],
      '127.5.0.1': ['192.168.2.1', '192.291.12.2', 'router.what.com'],
      '127.2.5.1': ['192.16.6.1',  '192.291.12.2', 'router.what.com'],
      '127.2.1.1': ['192.16.2.6',  '192.211.12.2', 'router.what.com'],
      '127.0.0.2': ['192.168.2.1', '192.291.12.2', 'router.what.com'],
    }
    
    var addrs = _.reduce(
      forceData,
      function (memo,addrs) {
        _.each(addrs, function(addr) {
          if (! memo[addr]) {
            memo[addr] = 1;
          }
        });
        return memo;
      },
      {}
    );
    
    var i = 0;
    var nodes = [];
    var addrs_idx_map = {};
    for (var addr in addrs) {
      nodes.push({nodeName: addr, group: 1});
      addrs_idx_map[addr] = i;
      i++;
    };
    
    var links = [];
    _.each(
      forceData,
      function (addrs) {
        if (addrs.length >= 2) {
          //We can skip the last element
          for (var i=0; i < addrs.length - 1; i++) {
            var source = addrs_idx_map[addrs[i]];
            var target = addrs_idx_map[addrs[i+1]];
            links.push({source: source, target: target, value: 2});
          }
        }
      }
    );

    return({nodes: nodes, links: links});
  }
  window.renderForce = function () {
    var data = processForceData();    
    
    var w = document.body.clientWidth,
        h = document.body.clientHeight,
        colors = pv.Colors.category19();
      
      var vis = new pv.Panel()
          .canvas($('#force-cont')[0])
          .width(w)
          .height(h)
          .fillStyle("white")
          .event("mousedown", pv.Behavior.pan())
          .event("mousewheel", pv.Behavior.zoom());
      
      var force = vis.add(pv.Layout.Force)
          .nodes(data.nodes)
          .links(data.links);
          //.nodes([{nodeName: '127.0.0.1', group: 1}, {nodeName: '192.168.1.1', group: 2}])
          //.links([{source: 1, target: 0, value: 1}]);
      
      force.link.add(pv.Line);
      
      force.node.add(pv.Dot)
          .size(function(d) {return (d.linkDegree + 4) * Math.pow(this.scale, -1.5)})
          .fillStyle(function(d) { return d.fix ? "brown" : colors(d.group) })
          .strokeStyle(function() { return this.fillStyle().darker() } )
          .lineWidth(1)
          .title(function(d) { return d.nodeName } )
          .event("mousedown", function () { return pv.Behavior.drag() })
          .event("drag", function () { return force });
      
      vis.render();
  }
});
