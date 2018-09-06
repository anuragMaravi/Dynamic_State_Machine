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
String userName = "test";
String password = "TeSt";
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

//States
List<String> statesList = new ArrayList<String>();
Map<String, Boolean> stateActivity = new HashMap<String, Boolean>();

void setup(){  
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
void draw(){
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
    println(arrOfStr[0] + " " + arrOfStr[1]);
    
    //Add new state to statesList
    if(!statesList.contains(arrOfStr[1]))
      statesList.add(arrOfStr[1]);
      
    println(statesList); 
      
    //Change activity of state based on Start/End  
    if(arrOfStr[0].equals("START")) 
      stateActivity.put(arrOfStr[1], true);
    if(arrOfStr[0].equals("END")) 
      stateActivity.put(arrOfStr[1], false);     
     println(stateActivity);
     
     
     //Adding new state on the UI  
    if(statesList.size() != 0){
    pushMatrix();
    translate(width*0.5, height*0.5);
    addNewState(0, 0, stateGap, statesList.size(), statesList);
    popMatrix();
    }     
       
  } else println("No new data");
     
} //Draw ends here


//Parse time from string and change it to unix timestamp
public long parseTime(String date){
  String[] arrOfStr = date.split("T|Z");
  String dat = arrOfStr[0] + " " + arrOfStr[1];
  String timestamp_data = "0";
  SimpleDateFormat datetimeFormatter1 = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss");
  try {
    Date lFromDate1 = datetimeFormatter1.parse(dat);
    Timestamp fromTS1 = new Timestamp(lFromDate1.getTime());

    timestamp_data = String.valueOf(fromTS1.getTime());
  }catch (java.text.ParseException e) {
    e.printStackTrace();
  }
  return Long.parseLong(String.valueOf(timestamp_data)) - 14400000;
  //return Integer.parseInt(String.valueOf(timestamp_data).substring(0, 10));
}

//Add new state ellipse on the UI
void addNewState(float x, float y, float radius, int npoints, List<String> statesList) {
  float angle = TWO_PI / npoints;
  int s = 0;
  beginShape();
  for (float a = 0; a < TWO_PI; a += angle) {  
    if(s!=npoints){
    float sx = x - cos(a) * radius;
    float sy = y - sin(a) * radius;
    fill(255); 
    if(stateActivity.get(statesList.get(s)))
      fill(118,238,222);
    else fill(255);
    ellipse(sx, sy, stateRadius, stateRadius);
    textSize(16);
    fill(0);    
    textAlign(CENTER, CENTER);
    text(statesList.get(s) + " " + stateActivity.get(statesList.get(s)), sx, sy);
    println(s + " " + npoints);
    s++;
    }
  }
  endShape(CLOSE);
}
