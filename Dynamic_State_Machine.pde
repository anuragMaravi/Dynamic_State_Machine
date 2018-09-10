import java.sql.Timestamp;
import java.util.Date;
import java.text.SimpleDateFormat;

import com.rabbitmq.client.*;
import java.io.IOException;
import java.util.concurrent.TimeoutException;

import java.util.Arrays;
import java.util.List;
import java.util.Map;


//RabbitMQ Configuration
String EXCHANGE_NAME = "master_exchange";
String userName = "";
String password = "";
String virtualHost = "/";
String hostName = "128.237.158.26";
String sensorId = "80ee9a0e-e420-4263-9629-46ce4c3f7ae4";
int port = 5672;

//Message from the broker
String message = "";
String dateD = "";
String eventName = "";

//States on UI
int stateRadius = 150;
int stateGap = 200;
int numState = 0;

//States for V0 which has no conditions on transition
List < String > statesList = new ArrayList < String > ();
Map < String, Boolean > stateActivity = new HashMap < String, Boolean > ();

//Values from configuration file
JSONObject configJson;
List < String > eventsList = new ArrayList < String > ();
Map < String, JSONArray > stateTransition = new HashMap < String, JSONArray > ();
String currentState = "";




void setup() {
 size(1200, 720);
 noLoop();

 //*************************
 //Data from RabbitMQ
 
 try{
   ConnectionFactory factory = new ConnectionFactory();
   factory.setUsername(userName);
   factory.setPassword(password);
   factory.setVirtualHost(virtualHost);
   factory.setHost(hostName);
   factory.setPort(port);
   Connection connection = factory.newConnection();
   Channel channel = connection.createChannel();

   channel.exchangeDeclare(EXCHANGE_NAME, BuiltinExchangeType.DIRECT);
   String queueName = channel.queueDeclare().getQueue();
   channel.queueBind(queueName, EXCHANGE_NAME, sensorId);

   System.out.println(" [*] Waiting for messages. To exit press CTRL+C");

   Consumer consumer = new DefaultConsumer(channel) {
     @Override
     public void handleDelivery(String consumerTag, Envelope envelope,
                                AMQP.BasicProperties properties, byte[] body) throws IOException {
       message = new String(body, "UTF-8");
       message = message.replace('\'','\"');
       message = message.replace("u\"","\"");
       redraw();
     }
   };
   channel.basicConsume(queueName, true, consumer);

  } catch(IOException i) {
    println(i);
  } catch(TimeoutException i) {
    println(i);
  }  


 


} //Setup ends here

int i = 0;
void draw() {
 background(0);

 //*************************
 long eventTime = 0;
 if(message.length() != 0){
   JSONObject json = parseJSONObject(message);
   JSONObject fields = json.getJSONObject("fields");
   eventName = fields.getString("value");
   dateD = String.valueOf(json.getString("time"));
   eventTime = parseTime(dateD); //Time in GMT
   //println(eventTime);

   //Logging
     println("\n" + i + " "  + dateD + " " + eventName);
     i++;
   //EventName on UI
   fill(255);
   textSize(16);
   text(eventName,80,40);

   //Split the message
   String[] arrOfStr = {};
   arrOfStr = eventName.split(":");
   //println(arrOfStr[0] + " " + arrOfStr[1]);
 
 
     //----------------------------------------------------
     /***From configuration file 
     Using the concept of finite state machine
     **/
     String dat = arrOfStr[1]; // Input stream goes here
     println("InputData: ", dat);
     
     //From configuration file
     configJson = loadJSONObject("configuration.json");
     eventsList = getEvents(); //contains a list of events/transistion conditions
     println("Valid Event: " + eventValid(dat)); //Event message comes here
     if (eventValid(dat)) { //Event message comes here
      println("Current State: ", getCurrentState());
      String action = getNextState(getCurrentState(), dat);
      println("Next State: ", action);
      if (!action.equals("Error")) {
       setCurrentState(action);
       
       //Add new state to statesList
       if(!statesList.contains(getCurrentState()))
         statesList.add(getCurrentState());
       println("States List:",statesList); 
       //Reset all values to false
       for (Map.Entry<String, Boolean> entry : stateActivity.entrySet()) {
          stateActivity.put(entry.getKey(), false);
       }
       stateActivity.put(getCurrentState(), true);
       
       //Text
       fill(255);
       textSize(16);
       text(getCurrentState(), width/2,height - 40);
      } else {
       println("No transition for this event on current state");
       fill(255);
       textSize(16);
       text("No transition for this event on current state", width/2, height - 40);
      }
     }
     println("Updated Current State:", getCurrentState());

    //----------------------------------------------------

   //This should run in each iteration to update the UI
   if(statesList.size() != 0){
     pushMatrix();
     translate(width*0.5, height*0.5);
     addNewState(0, 0, stateGap, statesList.size(), statesList);
     popMatrix();
   }     

 } else println("No new data");




} //Draw ends here

//*******************************
//Finite State Machine Conditions
//*******************************

//Getting the events/transitions from the configuration file, returns a list of valid events
//#######ToDo: Use the events type to smooth the data
List < String > getEvents() {
 List < String > list = new ArrayList < String > ();
 JSONArray events = configJson.getJSONArray("events");
 for (int e = 0; e < events.size(); e++) {
  JSONObject obj = events.getJSONObject(e);
  list.add(obj.getString("name"));
 }
 return list;
}

//Check if the eventMessage from the sensor is valid for this state machine or it is a noise
Boolean eventValid(String eventMessage) {
 if (eventsList.contains(eventMessage))
  return true;
 else
  return false;
}

//Add states and its transitions
String getNextState(String currentState, String transition) {
 JSONArray states = configJson.getJSONArray("states");
 for (int s = 0; s < states.size(); s++) {
  JSONObject obj = states.getJSONObject(s);
  String stateName = obj.getString("name");
  if (stateName.equals(currentState)) {
   JSONArray transitionC = obj.getJSONArray("transition");
   for (int t = 0; t < transitionC.size(); t++) {
    JSONObject tObject = transitionC.getJSONObject(t);
    if (tObject.getString("event").equals(transition)) {
     return tObject.getString("action");
    } else {
     println("Transition not found", t);
    }
   }
   break;
  } else println("State not found at", s);
 }
 return "Error";
}

//Gives the current state
String getCurrentState() {
 if (currentState.equals(""))
  return configJson.getString("initialState");
 else
  return currentState;
}

//Set the current state
void setCurrentState(String nextState) {
 currentState = nextState;
}


//************************
//Data from rabbitMQ Part
//************************


//Parse time from string and change it to unix timestamp
public long parseTime(String date) {
 String[] arrOfStr = date.split("T|Z");
 String dat = arrOfStr[0] + " " + arrOfStr[1];
 String timestamp_data = "0";
 SimpleDateFormat datetimeFormatter1 = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss");
 try {
  Date lFromDate1 = datetimeFormatter1.parse(dat);
  Timestamp fromTS1 = new Timestamp(lFromDate1.getTime());
  timestamp_data = String.valueOf(fromTS1.getTime());
 } catch (java.text.ParseException e) {
  e.printStackTrace();
 }
 return Long.parseLong(String.valueOf(timestamp_data)) - 14400000;
 //return Integer.parseInt(String.valueOf(timestamp_data).substring(0, 10));
}

//*******
//UI Part
//*******

//Add new state ellipse on the UI
void addNewState(float x, float y, float radius, int npoints, List < String > statesList) {
 float angle = TWO_PI / npoints;
 int s = 0;
 beginShape();
 for (float a = 0; a < TWO_PI; a += angle) {
  if (s != npoints) {
   float sx = x - cos(a) * radius;
   float sy = y - sin(a) * radius;
   fill(255);
   if (stateActivity.get(statesList.get(s)))
    fill(253, 190, 45);
   else fill(255);
   ellipse(sx, sy, stateRadius, stateRadius);
   textSize(16);
   fill(0);
   textAlign(CENTER, CENTER);
   text(statesList.get(s), sx, sy);
   println(s + " " + npoints);
   s++;
  }
 }
 endShape(CLOSE);
}

//Arrow Between states
void arrow(int x1, int y1, int x2, int y2) {
 stroke(255);
 line(x1, y1, x2, y2);
 pushMatrix();
 translate(x2, y2);
 float a = atan2(x1 - x2, y2 - y1);
 rotate(a);
 line(0, 0, -10, -10);
 line(0, 0, 10, -10);
 popMatrix();
}
