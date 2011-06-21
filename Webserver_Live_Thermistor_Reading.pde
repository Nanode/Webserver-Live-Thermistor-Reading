//Derived from: http://www.arduino.cc/playground/ComponentLib/Thermistor and https://github.com/dingram/Nanode/blob/master/Ethershield_webserver/Ethershield_webserver.pde
#include "EtherShield.h"
#include <math.h>
#define ThermistorPIN 0                 // Analog Pin 0
                                        // set to the measured Vcc.
float pad = 10950;                       // balance/pad resistor value, set this to
                                         // the measured resistance of your pad resistor
float thermr = 10000;                   // thermistor nominal resistance
char tempBuf[32] = {0};
float temp;
float Thermistor(int RawADC) {
long Resistance;  
float Temp;  // Dual-Purpose variable to save space.

Resistance=((1024 * pad / RawADC) - pad); 
Temp = log(Resistance); // Saving the Log(resistance) so not to calculate  it 4 times later
Temp = 1 / (0.001129148 + (0.000234125 * Temp) + (0.0000000876741 * Temp * Temp * Temp));
Temp = Temp - 273.15;  // Convert Kelvin to Celsius                      

// Uncomment this line for the function to return Fahrenheit instead.
//temp = (Temp * 9.0)/ 5.0 + 32.0;                  // Convert to Fahrenheit
return Temp;                                      // Return the Temperature
}

static uint8_t mymac[6] = {0x4e,0x41,0x4e,0x4f,0x44,0x00 };

static uint8_t myip[4] = {0,0,0,0};
static uint8_t mynetmask[4] = {0,0,0,0};
// Default Gateway, DNS server and DHCP Server addresses.
// Populated as part of DHCP address allocation
static uint8_t gwip[4] = { 0,0,0,0 };
static uint8_t dnsip[4] = { 0,0,0,0 };
static uint8_t dhcpsvrip[4] = { 0,0,0,0 };

#define DHCPLED 6
#define MYWWWPORT 80
#define BUFFER_SIZE 1023
static uint8_t buf[BUFFER_SIZE+1];

boolean gotIp = false;

// The ethernet shield
EtherShield es=EtherShield();

uint16_t http200ok(void)
{
  return(es.ES_fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 200 OK\r\nContent-Type: text/html\r\nPragma: no-cache\r\n\r\n")));
}

void print_mac(uint8_t *buf, uint16_t *plen, uint8_t *mac) {
  char msg[18] = {
    0  };
  sprintf(msg, "%02x:%02x:%02x:%02x:%02x:%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  *plen=es.ES_fill_tcp_data(buf,*plen,msg);
}

void print_ip(uint8_t *buf, uint16_t *plen, uint8_t *ip) {
  char msg[15] = {0};
  sprintf(msg, "%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);
  *plen=es.ES_fill_tcp_data(buf,*plen,msg);
}

// prepare the webpage by writing the data to the tcp send buffer
uint16_t print_webpage(uint8_t *buf)
{
  uint16_t plen;  
  plen=http200ok();
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<html><head><title>Nanode is alive!</title></head><body>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<center><h1>Congratulations! Your Nanode lives!</h1>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<hr><p>Your <a href=\"http://nanode.eu/\">Nanode</a> is now "));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("happily connected to your network and serving simple web pages."));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<br>In't that exciting?</p>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<p><strong>Temperature:</strong> "));  
  plen=es.ES_fill_tcp_data(buf, plen, tempBuf); //print the temperature buffer to the webpage buffer
  
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("</p></center><hr>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<h2>Details</h2>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<p>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<strong>MAC:</strong> "));
  print_mac(buf, &plen, mymac);

  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<br><strong>IP:</strong> "));
  print_ip(buf, &plen, myip);

  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<br><strong>DHCP server:</strong> "));
  print_ip(buf, &plen, dhcpsvrip);

  char msg[15]={0};
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<br>"));
  sprintf(msg, "%lu", millis());
  plen=es.ES_fill_tcp_data(buf,plen,msg);
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR(" ms since boot"));

  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("</p><hr>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<p style=\"text-align:right;color:#999\">Sketch v1 <a href=\"http://nanode.eu\">nanode.eu</a></p>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("</body></html>"));

  return(plen);
}

void printIP( uint8_t *buf ) {
  for( int i = 0; i < 4; i++ ) {
    Serial.print( buf[i], DEC );
    if( i<3 )
      Serial.print( "." );
  }
}


void setup(){
  pinMode(DHCPLED, OUTPUT);
  // LED off: getting ready
  digitalWrite(DHCPLED, HIGH);

  Serial.begin(19200);
  Serial.println("Web server test");

  // Initialise SPI interface
  es.ES_enc28j60SpiInit();

  // initialize enc28j60
  es.ES_enc28j60Init(mymac, 8);
}

void loop(){
  long firstDhcpRequest = millis();
  long lastDhcpRequest = millis();
  uint8_t dhcpState = 0;
  boolean gotIp = false;
  uint16_t plen, dat_p;
  long lastLEDTime = millis();
  int lastLED = HIGH, ledDelay=250;

  Serial.println("Sending initial DHCP Discover");
  es.ES_dhcp_start( buf, mymac, myip, mynetmask,gwip, dnsip, dhcpsvrip );

  while(1) {
    // read packet, handle ping and wait for a tcp packet:
    plen = es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf);
    dat_p=es.ES_packetloop_icmp_tcp(buf,plen);

    // flash LED while acquiring address
    if (lastLEDTime + ledDelay < millis()) {
      lastLED = (lastLED == HIGH) ? LOW : HIGH;
      lastLEDTime = millis();
      digitalWrite(DHCPLED, lastLED);
    }
    if ((firstDhcpRequest + 10000L) < millis()) {
      ledDelay = 100;
    }

    if(dat_p==0) {
      int retstat = es.ES_check_for_dhcp_answer( buf, plen);
      dhcpState = es.ES_dhcp_state();
      // we are idle here
      if( dhcpState != DHCP_STATE_OK && !gotIp ) {
        if (millis() > (lastDhcpRequest + 5000L) ){
          lastDhcpRequest = millis();
          // send dhcp
          Serial.println("Sending DHCP Discover");
          es.ES_dhcp_start( buf, mymac, myip, mynetmask,gwip, dnsip, dhcpsvrip );
        }
      } 
      else {
        if( !gotIp ) {
          // Display the results:
          Serial.print( "Visit: http://" );
          printIP( myip );
          Serial.println("/");
          gotIp = true;
          break;
        }
      }
    }
  }

  // init the ethernet/ip layer:
  // NOTE: this must happen *AFTER* DHCP, as we only have an IP at this point!
  es.ES_init_ip_arp_udp_tcp(mymac,myip, MYWWWPORT);

  // LED on: ready to process requests
  ledDelay = 100;
  lastLED = LOW;
  digitalWrite(DHCPLED, LOW);

  Serial.println("Waiting for requests...");

  while (1) {
    // read packet, handle ping and wait for a tcp packet:
    plen = es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf);
    dat_p=es.ES_packetloop_icmp_tcp(buf,plen);

    // turn request LED off after a delay
    if (lastLED==HIGH && lastLEDTime + ledDelay > millis()) {
      digitalWrite(DHCPLED, LOW);
    }

    /* dat_p will be unequal to zero if there is a valid
     * http get */
    if(dat_p==0){
      // no http request
      continue;
    }

    // flash LED while serving request
    lastLEDTime = millis();
    lastLED = HIGH;
    digitalWrite(DHCPLED, HIGH);

    Serial.println("Received request");
    // tcp port 80 begin
    if (strncmp("GET ",(char *)&(buf[dat_p]),4)!=0){
      // head, post and other methods:
      dat_p=http200ok();
      dat_p=es.ES_fill_tcp_data_p(buf,dat_p,PSTR("<h1>200 OK</h1>"));
      goto SENDTCP;
    }
  
    //begin thermistor read
    temp = Thermistor(analogRead(ThermistorPIN));
    dtostrf(temp, 3, 1, tempBuf);
    //dtostrf(floatVar, minStringWidthIncDecimalPoint, numVarsAfterDecimal, charBuf);
    //end thermistor read
  
    // just one web page in the "root directory" of the web server
    if (strncmp("/ ",(char *)&(buf[dat_p+4]),2)==0){
      dat_p=print_webpage(buf);
      goto SENDTCP;
    }
    else{
      dat_p=es.ES_fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 404 Not Found\r\nContent-Type: text/html\r\n\r\n"));
      dat_p=es.ES_fill_tcp_data_p(buf,dat_p,PSTR("<html><head><title>Not Found</title></head><body><h1>404 Not Found</h1></body></html>"));
      goto SENDTCP;
    }
SENDTCP:
    es.ES_www_server_reply(buf,dat_p); // send web page data
    // tcp port 80 end
  }

}

