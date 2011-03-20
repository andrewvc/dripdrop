function DripDrop() { 
  /* JavaScript object for DripDrop Messages */
  this.Message = function(name,opts) {
    this.name = name;
    if (opts && opts.body) {
      this.body = opts.body;
    };
    
    this.head = (opts && opts.head !== undefined) ? opts.head : {empty:''};

    this.jsonEncoded = function() {
      return JSON.stringify({name: this.name, head: this.head, body: this.body});
    };   
  };
  
  /* A DripDrop friendly WebSocket Object. 
     This automatically converts messages to DD.Message objects.
     Additionally, this uses friendlier callback methods, closer to the DripDrop
     server-side API, like onOpen, onReceive, onError, and onClose. */
  this.WebSocket = function(url) {
    this.socket = new WebSocket(url);
    
    this.onOpen = function(callback) {
      this.socket.onopen = callback;
      return this;
    };
    
    this.onReceive = function(callback) {
      this.socket.onmessage = function(wsMessage) {
        var json = $.parseJSON(wsMessage.data)
        var message = new DD.Message(json.name, {head: json.head, body: json.body});
        
        callback(message);
      }
      return this;
    };
    
    this.onClose = function(callback) {
      this.socket.onclose = callback;
      return this;
    };

    this.onError = function(callback) {
      this.socket.onerror = callback;
      return this;
    };

    this.sendMessage = function(message) {
      this.socket.send(message.jsonEncoded());
      return this;
    };
  };

  this.HTTPResponse = function() {
    
  };
   
  /* A DripDrop friendly HTTP Request. */
  this.HTTPClient = function(url) {
    this.url = url;
     
    this.onReceive = function(data) {};
    this.sendMessage = function() {
      var response = new this.HTTPResponse;
      $.post(this.url, function(json) {
        this.onReceive(new DD.Message(json.name, {head: json.head, body: json.body}));
      });
    };
  };

  /* An Object for reperesenting pipeline processing. 
     Ex:
     var mypl = new DD.Pipeline; 
     mypl.stages.push(new DD.PipelineStage{'namecapper','Name Capper', 
                    function(message) { message.name = message.name.toUpperCase() });
     mypl.execute(message); //Message must be a valid DD.Message

  
     All functions must either return a message, or false.
     If false is returned the pipeline short-circuits and returns false, not running
     subsequent stages */
  this.PipelineStage = function(id,name,action) {
    this.id     = id;
    this.name   = name;
    this.action = action;
  };
  
  this.Pipeline = function() {
    this.stages = [];
    
    this.execute = function(message) {
      if (this.stages.length == 0) {
        return null;
      };
      
      for (var i=0,l=this.stages.length; i < l; i++) {
        var stage = this.stages[i];
        message = stage.action(message);
      };
      
      return message;
    };
  };
};

//Use this as shorthand
DD = new DripDrop;
