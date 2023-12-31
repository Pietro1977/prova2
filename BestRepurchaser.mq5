//+------------------------------------------------------------------+
//|                                              BestRepurchaser.mq5 |
//|                                Copyright 2023, Centropolis corp. |
//|                                                   centropolis.tk |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Centropolis corp."
#property link      "centropolis.tk"
#property version   "1.00"

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object

input string SymbolsE="EURUSD,GBPUSD,USDCHF,USDJPY,NZDUSD,AUDUSD,USDCAD";//Symbols
input double StepPercent=0.5;//Step Percent
input double StepMultiplier=1.05;//Step Multiplier
input double LotMultiplier=1.05;//Lot Multiplier
input double BackPercent=90.0;//Back Percent
input int LastBars=10;//Last Bars Count
input ENUM_TIMEFRAMES TimeframeE=PERIOD_M1;//Work Timeframe
input double RepurchaseLotE=0.01;//Fix Lot For Repurchase
input double DepositForRepurchaseLotE=0.00;//Deposit For Lot (if "0" then fix repurchase)
input int HoursToBreakE=50;//hours of work before restart (0 if no need to restart)
input int HistoryDaysLoadI=365;//Trade History Days
input int SLE=0;//Stop Loss
input int TPE=0;//Take Profit
input int MagicE=156;//First Magic
input bool bInitBuyE=true;//Init Buy Cycles
input bool bInitSellE=true;//Init Sell Cycles
input bool bInterfaceE=true;//Interface
input int SpreadPointsE=50;//МахSpread

int SlippageMaxOpen=100;//Slippage Open
int SlippageMaxClose=100;//Slippage Close

///.............necessary values for building virtual robots...........
string S[];//array with symbols
int CN[];//number of candles for trading (loading the last bars)
///..............................................................................

void ConstructArrays()//construct the necessary arrays
   {
      int SCount=1;
      for (int i = 0; i < StringLen(SymbolsE); i++)
         {
         if (SymbolsE[i] == ',')
            {
            SCount++;
            }
         }
      ArrayResize(S,SCount);//set the size of the symbol array
      ArrayResize(CN,SCount);//set the size of the array of using bars for each symbol
      int Hc=0;//obtained symbol index
      for (int i = 0; i < StringLen(SymbolsE); i++)//construct the symbol array
         {
         if (i == 0)//if just started
            {
            int LastIndex=-1;
            for (int j = i; j < StringLen(SymbolsE); j++)
               {
               if (StringGetCharacter(SymbolsE,j) == ',')
                  {
                  LastIndex=j;
                  break;
                  }
               }
            if (LastIndex != -1)//if no separating comma is found
               {
               S[Hc]=StringSubstr(SymbolsE,i,LastIndex);
               Hc++;
               }
            else
               {
               S[Hc]=SymbolsE;
               Hc++;
               }
            }          
         if (SymbolsE[i] == ',')
            {
            int LastIndex=-1;
            for (int j = i+1; j < StringLen(SymbolsE); j++)
               {
               if (StringGetCharacter(SymbolsE,j) == ',')
                  {
                  LastIndex=j;
                  break;
                  }
               }
            if (LastIndex != -1)//if no separating comma is found
               {
               S[Hc]=StringSubstr(SymbolsE,i+1,LastIndex-(i+1));
               Hc++;
               }
            else
               {
               S[Hc]=StringSubstr(SymbolsE,i+1,StringLen(SymbolsE)-(i+1));
               Hc++;
               }               
            }
         }
      for (int i = 0; i < ArraySize(S); i++)//set the requested number of bars
         {
         CN[i]=LastBars;
         }
   }
   

void CreateCharts()//create the chart objects
   {
   bool bAlready;
   int num=0;
   string TempSymbols[];
   string Symbols[];
   ConstructArrays();//prepare the arrays
   ArrayResize(TempSymbols,ArraySize(S));//temporary symbol array
   for (int i = 0; i < ArraySize(S); i++)//fill the temporary array with empty strings
      {
      TempSymbols[i]="";
      }
   for (int i = 0; i < ArraySize(S); i++)//calculate the required number of unique symbols
      {
      bAlready=false;
      for (int j = 0; j < ArraySize(TempSymbols); j++)
         {
         if ( S[i] == TempSymbols[j] )
            {
            bAlready=true;
            break;
            }
         }
      if ( !bAlready )//if there is no such chart, add it
         {
         for (int j = 0; j < ArraySize(TempSymbols); j++)
            {
            if ( TempSymbols[j] == "" )
               {
               TempSymbols[j] = S[i];
               break;
               }
            }
         num++;         
         }
      }      
   ArrayResize(Symbols,num);//assign size to symbol arrays
   for (int j = 0; j < ArraySize(Symbols); j++)//now we can fill them in
      {
      Symbols[j]=TempSymbols[j];
      } 
   ArrayResize(Charts,num);//set the size of the chart array
   int tempcnum=0;
   for (int j = 0; j < num; j++)//determine the maximum number of required candles for the largest variant
      {
      if ( CN[j] > tempcnum ) tempcnum=CN[j];
      }
   Chart::TCN=tempcnum;
   for (int j = 0; j < ArraySize(Charts); j++)//fill in all the names and set the dimensions of all timeseries of each chart
      {
      Charts[j] = new Chart();
      Charts[j].lastcopied=0;
      Charts[j].BasicName=Symbols[j];
      ArrayResize(Charts[j].CloseI,tempcnum+2);//assign size to symbol arrays
      ArrayResize(Charts[j].OpenI,tempcnum+2);//assign size to symbol arrays
      ArrayResize(Charts[j].HighI,tempcnum+2);//assign size to symbol arrays
      ArrayResize(Charts[j].LowI,tempcnum+2);//assign size to symbol arrays
      ArrayResize(Charts[j].TimeI,tempcnum+2);//assign size to symbol arrays
      Charts[j].CurrentSymbol = Charts[j].BasicName;//symbol
      Charts[j].Timeframe = TimeframeE;//period
      }
   ArrayResize(Bots,ArraySize(S));//set the size of the bot array      
   }
   
void CreateInstances()//attach all virtual robots to charts
   {
   for (int i = 0; i < ArraySize(S); i++)
      {
      for (int j = 0; j < ArraySize(Charts); j++)
         {
         if ( Charts[j].BasicName == S[i] )
            {
            Bots[i] = new BotInstance(i,j);
            break;
            } 
         }
      }
   }
   
void AllChartsTick()//ticks of all charts
   {
   for (int i = 0; i < ArraySize(Charts); i++)
      {
      Charts[i].ChartTick();
      }
   }
   
void AllBotsTick()//ticks of all bots
   {
   for (int i = 0; i < ArraySize(S); i++)
      {
      if ( Charts[Bots[i].chartindex].lastcopied >= Chart::TCN+1 ) Bots[i].InstanceTick();
      }
   }      

class Chart
   {
   public:
   datetime TimeI[];
   double CloseI[];
   double OpenI[];
   double HighI[];
   double LowI[];
   string BasicName;//base name that was in the substring
   string BasicSymbol;//basic instrument taken from the substring
   double ChartPoint;//size of the point of the current chart
   double ChartAsk;//chart Ask
   double ChartBid;//chart Bid
   
   datetime tTimeI[];//auxiliary array to control the emergence of a new bar
   
   static int TCN;//tcn
   
   string CurrentSymbol;//adjusted symbol
   ENUM_TIMEFRAMES Timeframe;//chart period
   int copied;//amount of data copied
   int lastcopied;//last amount of data copied
   datetime LastCloseTime;//last bar time
   MqlTick LastTick;
   
   Chart()
      {
      ArrayResize(tTimeI,2);
      }
   
   void ChartTick()//chart tick
      {
      SymbolInfoTick(CurrentSymbol,LastTick);
      ArraySetAsSeries(tTimeI,false);
      copied=CopyTime(CurrentSymbol,Timeframe,0,2,tTimeI);
      ArraySetAsSeries(tTimeI,true);
      if ( copied == 2 && tTimeI[1] > LastCloseTime )
         {
         ArraySetAsSeries(CloseI,false);                        
         ArraySetAsSeries(OpenI,false);                           
         ArraySetAsSeries(HighI,false);                        
         ArraySetAsSeries(LowI,false);                              
         ArraySetAsSeries(TimeI,false);                                                            
         lastcopied=CopyClose(CurrentSymbol,Timeframe,0,Chart::TCN+2,CloseI);
         lastcopied=CopyOpen(CurrentSymbol,Timeframe,0,Chart::TCN+2,OpenI);   
         lastcopied=CopyHigh(CurrentSymbol,Timeframe,0,Chart::TCN+2,HighI);   
         lastcopied=CopyLow(CurrentSymbol,Timeframe,0,Chart::TCN+2,LowI);
         lastcopied=CopyTime(CurrentSymbol,Timeframe,0,Chart::TCN+2,TimeI);
         ArraySetAsSeries(CloseI,true);
         ArraySetAsSeries(OpenI,true);
         ArraySetAsSeries(HighI,true);                        
         ArraySetAsSeries(LowI,true);
         ArraySetAsSeries(TimeI,true);         
         LastCloseTime=tTimeI[1];
         }
      ChartBid=LastTick.bid;
      ChartAsk=LastTick.ask;
      ChartPoint=SymbolInfoDouble(CurrentSymbol,SYMBOL_POINT);
      }
   };
int Chart::TCN = 0;   
Chart *Charts[];



class BotInstance//separate robot object
   {
   public:
   CPositionInfo  m_position;                   // trade position object
   CTrade         m_trade;                      // trading object   
   ///.............values for a particular robot..............
   int MagicF;//Magic
   string CurrentSymbol;//Symbol
   int chartindex;//index of the chart object the bot is to take a quote from
   ///..........................................................   

   
   ///constructor
   BotInstance(int index,int chartindex0)//load all data from hat using index, + chart index
      {
      chartindex=chartindex0;
      MagicF=MagicE+index;
      CurrentSymbol=Charts[chartindex].CurrentSymbol;
      m_trade.SetExpertMagicNumber(MagicF);
      }
   ///
   
   void InstanceTick()//internal robot tick
      {
      if ( bNewBar() ) Trade();
      }
      
   private:
   datetime Time0;
   bool bNewBar()//new bar
      {
      if ( Time0 < Charts[chartindex].TimeI[1] && Charts[chartindex].ChartPoint != 0.0 )
         {
         if (Time0 != 0)
            {
            Time0=Charts[chartindex].TimeI[1];
            return true;
            }
         else
            {
            Time0=Charts[chartindex].TimeI[1];
            return false;
            }
         }
      else return false;
      }
      
   //////************************************Main Logic************************************
   enum CYCLE_STATUS//cycle status ( buy/sell/absent )
     {
     BUY_CYCLE,
     SELL_CYCLE,
     NO_CYCLE
     };
   
   
   CYCLE_STATUS bActiveCycleDirection()//define the cycle activity
      {
      ulong ticket;
      bool ord;
      int OrdersG=0;
      CYCLE_STATUS Directon=NO_CYCLE;
      for ( int i=0; i<PositionsTotal(); i++ )
         {
         ticket=PositionGetTicket(i);
         ord=PositionSelectByTicket(ticket);      
         if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetString(POSITION_SYMBOL) == CurrentSymbol )
            {
            OrdersG++;
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) Directon=BUY_CYCLE;
            else  Directon=SELL_CYCLE;
            break;
            }
         }
      return Directon;
      }
   
   double StartPrice;//cycle start price
   
   CYCLE_STATUS LastCyclesStatus;
   void StartPriceControl()//cycle start price control
      {
      //Print("start price control");
      if (StartPrice == -1.0)//if the cycle is over, start a new one
         {
         //Print("start price control PPPPP");
         StartPrice = Charts[chartindex].CloseI[0];
         LastRepurchasePrice = StartPrice;
         }      
      }
   
   bool bLastCycleDirection;//direction of the last closed cycle
   void LastCycleDirectionControl()//last cycle direction control
      {
      bool ord;
      ENUM_DEAL_TYPE Deal;
      HistorySelect(TimeCurrent()-HistoryDaysLoadI*86400,TimeCurrent());
      bool bfind=false;
      int OwnPositions=0;
      ulong ticket0;
      
      RepurchasesCount=0;
      
      bool bOwnPositions=false;
      for ( int i=0; i<PositionsTotal(); i++ )
         {
         ticket0=PositionGetTicket(i);
         ord=PositionSelectByTicket(ticket0);      
         if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetString(POSITION_SYMBOL) == Charts[chartindex].CurrentSymbol )
            {
            bOwnPositions=true;
            break;
            }
         }
      
      if (bOwnPositions)
         {
         for ( int i=HistoryDealsTotal()-1; i>=0; i-- )
            {
            ulong ticket=HistoryDealGetTicket(i);
            ord=HistoryDealSelect(ticket);
            if ( ord && HistoryDealGetString(ticket,DEAL_SYMBOL) == CurrentSymbol 
            && HistoryDealGetInteger(ticket,DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(ticket,DEAL_MAGIC) == MagicF )//find the last entry deal
               {
               Deal=ENUM_DEAL_TYPE(HistoryDealGetInteger(ticket,DEAL_TYPE));
               if (Deal == DEAL_TYPE_BUY)
                  {
                  LastRepurchasePrice=HistoryDealGetDouble(ticket,DEAL_PRICE);//deal open price
                  bLastCycleDirection = true;   
                  bfind = true;
                  break;            
                  } 
               else if (Deal == DEAL_TYPE_SELL)
                  {
                  LastRepurchasePrice=HistoryDealGetDouble(ticket,DEAL_PRICE);//deal open price
                  bLastCycleDirection = false;
                  bfind=true;
                  break;               
                  }
               }
            }
            
         if (bfind)//if the end of the cycle is found, then we can find its beginning (counting the number of rebuys along the way)
            {
            for ( int i=HistoryDealsTotal()-1; i>=0; i-- )//search for the first entry deal
               {
               ulong ticket=HistoryDealGetTicket(i);
               ord=HistoryDealSelect(ticket);
               if ( ord && HistoryDealGetString(ticket,DEAL_SYMBOL) == CurrentSymbol 
               && HistoryDealGetInteger(ticket,DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(ticket,DEAL_MAGIC) == MagicF )//find the last entry deal
                  {
                  Deal=ENUM_DEAL_TYPE(HistoryDealGetInteger(ticket,DEAL_TYPE));
                  if (Deal == DEAL_TYPE_BUY && !bLastCycleDirection)//if a sell cycle has already been found and we suddenly found the previous, opposite one, then interrupt
                     {
                     //Print("break buy");
                     break;
                     } 
                  else if (Deal == DEAL_TYPE_SELL && bLastCycleDirection)//if a buy cycle has already been found and we suddenly found the previous, opposite one, then interrupt
                     {
                     //Print("break sell");
                     break;
                     }
                  }
               if ( ord && HistoryDealGetString(ticket,DEAL_SYMBOL) == CurrentSymbol 
               && HistoryDealGetInteger(ticket,DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(ticket,DEAL_MAGIC) == MagicF )//find the last entry deal
                  {
                  Deal=ENUM_DEAL_TYPE(HistoryDealGetInteger(ticket,DEAL_TYPE));
                  if (Deal == DEAL_TYPE_BUY)
                     {
                     //Print("repurchase count buy ++");
                     RepurchasesCount++;
                     } 
                  else if (Deal == DEAL_TYPE_SELL)
                     {
                     //Print("repurchase count sell ++");
                     RepurchasesCount++;
                     }
                  }
               }         
            }         
         }
      }
   
   int RepurchasesCount;
   void StartCycleDirectionControl()//start pulling up the direction of the last cycle and the last rebuy price
      {
      bool ord;
      ENUM_DEAL_TYPE Deal;
      HistorySelect(TimeCurrent()-HistoryDaysLoadI*86400,TimeCurrent());
      
      bool bfind=false;
      bool bfindstartprice=false;
      ulong ticket0;
      
      RepurchasesCount=0;
      
      bool bOwnPositions=false;
      for ( int i=0; i<PositionsTotal(); i++ )
         {
         ticket0=PositionGetTicket(i);
         ord=PositionSelectByTicket(ticket0);      
         if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetString(POSITION_SYMBOL) == Charts[chartindex].CurrentSymbol )
            {
            bOwnPositions=true;
            break;
            }
         } 
         
      if (bOwnPositions)
         {
         for ( int i=HistoryDealsTotal()-1; i>=0; i-- )//search for the last entry deal
            {
            ulong ticket=HistoryDealGetTicket(i);
            ord=HistoryDealSelect(ticket);
            if ( ord && HistoryDealGetString(ticket,DEAL_SYMBOL) == CurrentSymbol 
            && HistoryDealGetInteger(ticket,DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(ticket,DEAL_MAGIC) == MagicF )//find the last entry deal
               {
               Deal=ENUM_DEAL_TYPE(HistoryDealGetInteger(ticket,DEAL_TYPE));
               if (Deal == DEAL_TYPE_BUY)
                  {
                  StartPrice=HistoryDealGetDouble(ticket,DEAL_PRICE);//deal open price
                  bLastCycleDirection = true;
                  bfind=true;  
                  break;             
                  } 
               else if (Deal == DEAL_TYPE_SELL)
                  {
                  StartPrice=HistoryDealGetDouble(ticket,DEAL_PRICE);//deal open price
                  bLastCycleDirection = false;
                  bfind=true;
                  break;               
                  }
               }
            }
         
         if (bfind)//if the end of the cycle is found, then we can find its beginning (counting the number of rebuys along the way)
            {
            for ( int i=HistoryDealsTotal()-1; i>=0; i-- )//search for the first entry deal
               {
               ulong ticket=HistoryDealGetTicket(i);
               ord=HistoryDealSelect(ticket);
               if ( ord && HistoryDealGetString(ticket,DEAL_SYMBOL) == CurrentSymbol 
               && HistoryDealGetInteger(ticket,DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(ticket,DEAL_MAGIC) == MagicF )//find the last entry deal
                  {
                  Deal=ENUM_DEAL_TYPE(HistoryDealGetInteger(ticket,DEAL_TYPE));
                  if (Deal == DEAL_TYPE_BUY && !bLastCycleDirection)//if a sell cycle has already been found and we suddenly found the previous, opposite one, then interrupt
                     {
                     break;
                     } 
                  else if (Deal == DEAL_TYPE_SELL && bLastCycleDirection)//if a buy cycle has already been found and we suddenly found the previous, opposite one, then interrupt
                     {
                     break;
                     }
                  }
               if ( ord && HistoryDealGetString(ticket,DEAL_SYMBOL) == CurrentSymbol 
               && HistoryDealGetInteger(ticket,DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetInteger(ticket,DEAL_MAGIC) == MagicF )//find the last entry deal
                  {
                  Deal=ENUM_DEAL_TYPE(HistoryDealGetInteger(ticket,DEAL_TYPE));
                  if (Deal == DEAL_TYPE_BUY)
                     {
                     StartPrice=HistoryDealGetDouble(ticket,DEAL_PRICE);//deal open price
                     RepurchasesCount++;
                     bfindstartprice=true;  
                     } 
                  else if (Deal == DEAL_TYPE_SELL)
                     {
                     StartPrice=HistoryDealGetDouble(ticket,DEAL_PRICE);//deal open price
                     RepurchasesCount++;
                     bfindstartprice=true;
                     }
                  }
               }         
            }
    
         if (bfind)
            {
            LastRepurchasePrice=-1.0;   
            if ( MathRand()/32767.0 > 0.5 ) bLastCycleDirection = true;
            else bLastCycleDirection = false;         
            }          
         }        
      }   
   
   /////////////////////////////////////////////////////////////////////////////////////////
   
   bool bFirstAction;//whether the start action has occurred
   int Starts;
   void StartAction()//start action (here you need to determine the state of the active cycle, if it exists, and all its parameters)
      {
      LastCyclesStatus = bActiveCycleDirection();//define the current cycle status
      if (LastCyclesStatus == NO_CYCLE && StartPrice != -1.0)
         {
         StartPrice = Charts[chartindex].CloseI[0];//set data to zero if there are no active cycles         
         LastRepurchasePrice = StartPrice;//set data to zero if there are no active cycles
         }
      else
         {
         StartCycleDirectionControl();
         }
      bFirstAction=true;
      LastBreak=TimeCurrent();
      Starts++;
      }
   
   void BreakAction()//
      {
      LastCyclesStatus = NO_CYCLE;//define the status of the current cycle
      StartPrice = -1.0;
      LastRepurchasePrice = -1.0;
      bFirstAction=true;
      LastBreak=TimeCurrent();
      Starts++;
      }   
   
   //HoursToBreakE
   datetime LastBreak;
   bool bBreak;
   void BreakControl()//break control
      {
      //Print("Bc");
      //Print(int(TimeCurrent()-LastBreak)/(60.0*60.0));
      if ( !bBreak && int(TimeCurrent()-LastBreak)/(60.0*60.0)  >= HoursToBreakE && Starts > 0 && OrdersT() > 0 )
         {
         bBreak=true;
         //Print("break");
         }
      else if (bBreak && OrdersT() == 0)
         {
         bBreak=false;
         bFirstAction=false;
         LastBreak=TimeCurrent();         
         //Print("end break");
         }         
      }
   
   void Trade()//obligatory function triggered at EACH BAR for a specific robot associated with a specific chart
      {
      //Close[0]   -->   Charts[chartindex].CloseI[0]
      //Open[0]   -->   Charts[chartindex].OpenI[0]
      //High[0]   -->   Charts[chartindex].HighI[0]
      //Low[0]   -->   Charts[chartindex].LowI[0]
      //Time[0]   -->   Charts[chartindex].TimeI[0]      
      
      //Print("Trade");

      CalculateFirstStaticForCorrection();
      if (HoursToBreakE != 0) BreakControl();
      
      if (bBreak)
         {
         CloseAllI(-1);
         }
      else
         {
         if (!bFirstAction) StartAction();//start action
          //
         //Print(IntegerToString(LastCyclesStatus));
         //Close LAST
         if ( LastCyclesStatus != NO_CYCLE )
            {
               if (LastCyclesStatus == BUY_CYCLE && StartPrice != -1.0)//if the last buy cycle needs to be closed
                  {
                  //Print("close buy 111111111111");
                  if (bCloseBuy())
                     {
                     CloseBuyF();
                     StartPriceControl();
                     //Print("close buy");         
                     }
                  }
               if (LastCyclesStatus == SELL_CYCLE && StartPrice != -1.0)//if the last sell cycle needs to be closed
                  {
                  //Print("close sell 111111111111");
                  if (bCloseSell())
                     {
                     CloseSellF();
                     StartPriceControl();     
                     //Print("close sell");             
                     }
                  }
            }
            
         //Open NEW     
         if (bInitBuyE && bInitSellE)//if both kinds of cycles are allowed
            {
            //Print("AZAZAZAZAZA");
            CalculateCorrectionLot();
            if (bNewRepurchaseBuy())
               {
               BuyF();
               LastCycleDirectionControl();
               }
            else if (bNewRepurchaseSell())
               {
               SellF();
               LastCycleDirectionControl();
               }                     
            }
         else if (bInitBuyE)//if buy cycles are allowed
            {
            CalculateCorrectionLot();
            if (bNewRepurchaseBuy())
               {
               BuyF();
               LastCycleDirectionControl();
               }
            }
         else if (bInitSellE)//if sell cycles are allowed
            {
            CalculateCorrectionLot();
            if (bNewRepurchaseSell())
               {
               SellF();
               LastCycleDirectionControl();
               }                  
            }         
         }
      }
      
   double OptimalLot(Chart &ChartParams)//function for calculating the lot included in the trading function
      {
      return L*RepurchaseLotE * MathPow(LotMultiplier,RepurchasesCount);
      }
   
   //correction
   static double K0;//base coefficient
   double L;//lot multiplier
   void CalculateFirstStaticForCorrection()
      {
      //Close[0]   -->   Charts[chartindex].CloseI[0]
      //Open[0]   -->   Charts[chartindex].OpenI[0]
      //High[0]   -->   Charts[chartindex].HighI[0]
      //Low[0]   -->   Charts[chartindex].LowI[0]
      //Time[0]   -->   Charts[chartindex].TimeI[0] 
      if (chartindex==0)
         {
         double Summ=0.0;
         double Mid;
         if (ArraySize(Charts[chartindex].CloseI) > 0)
            {
            if (Charts[chartindex].CloseI[ArraySize(Charts[chartindex].CloseI)-1] > 0)
               {
               for ( int i=0; i<ArraySize(Charts[chartindex].CloseI); i++)
                  {
                  Summ+=(Charts[chartindex].HighI[i]-Charts[chartindex].LowI[i]);
                  }
               Mid = Summ/ArraySize(Charts[chartindex].CloseI);
               K0 = (Mid / SymbolInfoDouble(Charts[chartindex].CurrentSymbol,SYMBOL_POINT)) * SymbolInfoDouble(Charts[chartindex].CurrentSymbol,SYMBOL_TRADE_TICK_VALUE);
               }
            else
               {
               K0 = -1.0;
               }
            }
         else
            {
            K0 = -1.0;
            }         
         }
      }
   
   void CalculateCorrectionLot()
      {
      double Summ=0.0;
      double Mid;
      for ( int i=0; i<ArraySize(Charts[chartindex].CloseI); i++)
         {
         Summ+=(Charts[chartindex].HighI[i]-Charts[chartindex].LowI[i]);
         }
      Mid = Summ/ArraySize(Charts[chartindex].CloseI);  
      if (K0 > 0.0)
         {
         L = K0 / ( (Mid / SymbolInfoDouble(Charts[chartindex].CurrentSymbol,SYMBOL_POINT)) * SymbolInfoDouble(Charts[chartindex].CurrentSymbol,SYMBOL_TRADE_TICK_VALUE) );
         }
      else
         {
         L = 0.0;
         }    
      }   
   //  
      
   //here you can add functionality or variables if the trading function turns out to be too complicated
   
   //double LastRepurchasePrice;//last rebuy price
   //double LastStartPrice;//price at which the last rebuy cycle started     
     
     
   bool bNewRepurchaseBuy()//permission for the next rebuy
      {
      double DeltaTemp = LastRepurchasePrice - Charts[chartindex].CloseI[0];//current movement towards rebuy if counting from the last rebuy
      
      //Print("bNewRepurchaseBUY");
      //Print("StartPrice = ",StartPrice);
      //Print("DeltaTemp = ",DeltaTemp);      
      //Print("LastCyclesStatus =",LastCyclesStatus);
      if (LastCyclesStatus == NO_CYCLE)//if the status says that there are no open cycles now and the price says the same thing because it has an incorrect value
            {
            if (DeltaTemp > 0 && DeltaTemp >  (StartPrice * (StepPercent/100.0) * MathPow(StepMultiplier,RepurchasesCount)) )
               {
               return true;
               }
            }         
      if (LastCyclesStatus == BUY_CYCLE)//if the cycle is already open and we rebuy
            {
            //Print("B B RepurchasesCount =",RepurchasesCount);
            //Print("B B Pow =",MathPow(StepMultiplier,RepurchasesCount));
            //Print("B B DeltaTemp =",DeltaTemp);
            //Print("B B StartPrice =",StartPrice); 
            //Print("B B DeltaDynamic =",StartPrice * (StepPercent/100.0) * MathPow(StepMultiplier,RepurchasesCount)); 
            if (DeltaTemp > 0 && DeltaTemp >  (StartPrice * (StepPercent/100.0) * MathPow(StepMultiplier,RepurchasesCount)) )
               {
               //Print("Repurchase Signal BUY");
               return true;
               }
            }
      return false;
      }  
      
   bool bNewRepurchaseSell()//permission for the next resell
      {
      double DeltaTemp = Charts[chartindex].CloseI[0] - LastRepurchasePrice;//current movement towards rebuy if counting from the last rebuy       
       
      //Print("bNewRepurchaseSELL");
      //Print("StartPrice = ",StartPrice);
      //Print("DeltaTemp = ",DeltaTemp);        
      //Print("LastCyclesStatus =",LastCyclesStatus);
      if (LastCyclesStatus == NO_CYCLE)//if the status says that there are no open cycles now and the price says the same thing because it has an incorrect value
            {
            //Print("S N DeltaTemp =",DeltaTemp);
            //Print("S N StartPrice =",StartPrice);
            if ( DeltaTemp > 0 && DeltaTemp >  (StartPrice * (StepPercent/100.0) * MathPow(StepMultiplier,RepurchasesCount)) )
               {
               return true;
               }
            }         
      if (LastCyclesStatus == SELL_CYCLE)//if the cycle is already open and we rebuy
            {
            //Print("S S DeltaTemp =",DeltaTemp);
            //Print("S S StartPrice =",StartPrice);
            //Print("B B DeltaDynamic =",StartPrice * (StepPercent/100.0) * MathPow(StepMultiplier,RepurchasesCount));             
            if (DeltaTemp > 0 && DeltaTemp >  (StartPrice * (StepPercent/100.0) * MathPow(StepMultiplier,RepurchasesCount)) )
               {
               //Print("Repurchase Signal SELL");
               return true;
               }
            }
            
      return false;      
      }
      
   bool bCloseBuy()//permission to close the entire series of orders/buy positions
      {
      double DeltaStart = StartPrice - LastRepurchasePrice;//current maximum movement towards rebuy      
      double DeltaPrice = Charts[chartindex].CloseI[0]-LastRepurchasePrice;//current rollback
      if (LastCyclesStatus == BUY_CYCLE)//if the cycle is already open and we rebuy
         {
         //Print("bCloseBuy");
         //Print("StartPrice = ",StartPrice);
         //Print("BuyDeltaStart = ",DeltaStart);
         //Print("BuyDeltaPrice = ",DeltaPrice);
         
         if ( DeltaStart > 0 && DeltaPrice > DeltaStart*(BackPercent/100.0) )
            {
            return true;
            }
         }
      return false;
      }  
      
   bool bCloseSell()//permission to close the entire series of orders/sell positions
      {
      double DeltaStart = LastRepurchasePrice - StartPrice;//current maximum movement towards resell       
      double DeltaPrice = LastRepurchasePrice - Charts[chartindex].CloseI[0];//current rollback
      if (LastCyclesStatus == SELL_CYCLE)//if the cycle is already open and we rebuy
         {
         //Print("bCloseSell");
         //Print("StartPrice = ",StartPrice);
         //Print("SellDeltaStart = ",DeltaStart);
         //Print("SellDeltaPrice = ",DeltaPrice);
         if ( DeltaStart > 0 && DeltaPrice > DeltaStart*(BackPercent/100.0) )
            {
            return true;
            }
         }
      return false;
      }
   
   void CloseCycleProcessing()//handle closing the rebuy cycle
      {
      LastCyclesStatus = bActiveCycleDirection();
      LastRepurchasePrice=-1.0;
      StartPrice=-1.0;
      RepurchasesCount=0;
      }
   
   //handlers
   
  
   void BuyAuxiliaryProcessing()//handling logic after a successful buy
      {
      LastCyclesStatus = bActiveCycleDirection();
      LastRepurchasePrice = Charts[chartindex].CloseI[0];
      }
   
   void SellAuxiliaryProcessing()//handling logic after a successful sell
      {
      LastCyclesStatus = bActiveCycleDirection();
      LastRepurchasePrice = Charts[chartindex].CloseI[0];
      }
        
   
   bool bStarted;//whether the rebuy cycle was started
   double LastRepurchasePrice;//last rebuy price
   bool bLastDirectionCycle;//direction of the last current rebuy/resell cycle (true/false)
   //////*****************************************************************************************
   
   ///trade functions
   int OrdersG()//number of the virtual robot open positions / orders
      {
      ulong ticket;
      bool ord;
      int OrdersG=0;
      for ( int i=0; i<PositionsTotal(); i++ )
         {
         ticket=PositionGetTicket(i);
         ord=PositionSelectByTicket(ticket);      
         if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetString(POSITION_SYMBOL) == CurrentSymbol )
            {
            OrdersG++;
            }
         }
      return OrdersG;
      }
      
   int OrdersT()//number of open positions of all robots
      {
      ulong ticket;
      bool ord;
      int OrdersT=0;
      for ( int i=0; i<PositionsTotal(); i++ )
         {
         ticket=PositionGetTicket(i);
         ord=PositionSelectByTicket(ticket);      
         if ( ord && bOurMagic0(PositionGetInteger(POSITION_MAGIC)) )
            {
            OrdersT++;
            }
         }
      return OrdersT;
      }
   
   /////////********/////////********//////////***********/////////trading functions code block
   void BuyF()//buy
      {
      double DtA;
      double SLTemp0=MathAbs(SLE);
      double TPTemp0=MathAbs(TPE); 
      
      double CorrectedLot;
   
      DtA=double(TimeCurrent())-GlobalVariableGet("TimeStart161_"+IntegerToString(MagicF));
      if ( (DtA > 0 || DtA < 0) )
         {
         CorrectedLot=GetLotWithoutError(OptimalLot(Charts[chartindex]));
         if ( CorrectedLot > 0.0 )
            {
            CheckForOpen(MagicF,ORDER_TYPE_BUY,Charts[chartindex].ChartBid,Charts[chartindex].ChartAsk,Charts[chartindex].CloseI[0],int(SLTemp0),int(TPTemp0),CorrectedLot,Charts[chartindex].CurrentSymbol,0,NULL,true,true,SpreadPointsE);
            }            
         }
      }
      
   void SellF()//sell
      {
      double DtA;
      double SLTemp0=MathAbs(SLE);
      double TPTemp0=MathAbs(TPE);
   
      double CorrectedLot;
   
      DtA=double(TimeCurrent())-GlobalVariableGet("TimeStart161_"+IntegerToString(MagicF));
      if ( (DtA > 0 || DtA < 0) )
         {
         CorrectedLot=GetLotWithoutError(OptimalLot(Charts[chartindex]));
         if ( CorrectedLot > 0.0 )
            {
            CheckForOpen(MagicF,ORDER_TYPE_SELL,Charts[chartindex].ChartBid,Charts[chartindex].ChartAsk,Charts[chartindex].CloseI[0],int(SLTemp0),int(TPTemp0),CorrectedLot,Charts[chartindex].CurrentSymbol,0,NULL,true,true,SpreadPointsE);
            }            
         }
      }
   
   void CheckForOpen(int Magic0,int OrdType,double PriceBid,double PriceAsk,double PriceClose0,int SL0,int TP0,double Lot0,string Symbol0,datetime Expiration0,string Comment0,bool bLotControl0,bool bSpreadControl0,int Spread0)
      {
      double LotTemp=Lot0;
      double SpreadLocal=double(SymbolInfoInteger(CurrentSymbol,SYMBOL_SPREAD));
      double LotAntiError=SymbolInfoDouble(CurrentSymbol,SYMBOL_VOLUME_MIN);
   
      if ( (SpreadLocal <= Spread0 && bSpreadControl0 == true ) || ( bSpreadControl0 == false )  )                    
         {   
         if ( bLotControl0 == false || DepositForRepurchaseLotE <= 0.0 )
            {
            LotTemp=Lot0;
            }
         if ( bLotControl0 == true && DepositForRepurchaseLotE > 0.0 )
            {
            LotTemp=Lot0*(AccountInfoDouble(ACCOUNT_BALANCE)/DepositForRepurchaseLotE);
            }
   
         LotAntiError=GetLotWithoutError(LotTemp);
         if ( LotAntiError <= 0 )
            {
            Print("TOO Low  Free Margin Level !");
            }
            
         if ( OrdType == ORDER_TYPE_SELL && LotAntiError > 0.0 )
            {
            GlobalVariableSet("TimeStart161_"+IntegerToString(MagicF),double(TimeCurrent()) );
            bool rez = m_trade.Sell(LotAntiError,Symbol0,Charts[chartindex].ChartBid,SL0 > 0.0 ? Charts[chartindex].ChartBid+SL0*Charts[chartindex].ChartPoint : 0,TP0 > 0.0 ? Charts[chartindex].ChartBid-TP0*Charts[chartindex].ChartPoint : 0);
            if (rez) SellAuxiliaryProcessing();
            }
         if ( OrdType == ORDER_TYPE_BUY && LotAntiError > 0.0 )
            {
            GlobalVariableSet("TimeStart161_"+IntegerToString(MagicF),double(TimeCurrent()) );
            bool rez = m_trade.Buy(LotAntiError,Symbol0,Charts[chartindex].ChartAsk,SL0 > 0.0 ? Charts[chartindex].ChartAsk-SL0*Charts[chartindex].ChartPoint : 0,TP0 > 0.0 ? Charts[chartindex].ChartAsk+TP0*Charts[chartindex].ChartPoint : 0);
            if (rez) BuyAuxiliaryProcessing();
            }                     
         }
      }
   
   double GetLotWithoutError(double InputLot)
      {
      double Free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double margin=0.0;
      bool bocm=OrderCalcMargin(ORDER_TYPE_BUY,CurrentSymbol,1.0,Charts[chartindex].CloseI[0],margin);
      double minLot = SymbolInfoDouble(CurrentSymbol,SYMBOL_VOLUME_MIN);
      double Max_Lot = SymbolInfoDouble(CurrentSymbol,SYMBOL_VOLUME_MAX);
      double Step = SymbolInfoDouble(CurrentSymbol,SYMBOL_VOLUME_STEP);
      double Lot13;
      int LotCorrection;
      LotCorrection=int(MathFloor(InputLot/Step));
      Lot13=LotCorrection*Step;   
      if(Lot13<=minLot) Lot13 = minLot;
      if(Lot13>=Max_Lot) Lot13 = Max_Lot;
      if( Lot13*margin>=Free ) Lot13=-1.0;
      return Lot13;
      }
   
   int CorrectLevels(int level0)
      {
      int rez;
      int ZeroLevel0=int(MathAbs(double(SymbolInfoInteger(CurrentSymbol,SYMBOL_TRADE_STOPS_LEVEL)))+MathAbs(double(SymbolInfoInteger(CurrentSymbol,SYMBOL_SPREAD)))+MathAbs(SlippageMaxOpen)+1);
   
      if ( MathAbs(level0) > ZeroLevel0 )
         {
         rez=int(MathAbs(level0));
         }
      else
         {
         rez=ZeroLevel0;
         } 
  
      return rez;
      }

   void CloseSellF()
      {
      ulong ticket;
      bool ord;
  
      int OwnPositions=0;
      for ( int i=0; i<PositionsTotal(); i++ )
         {
         ticket=PositionGetTicket(i);
         ord=PositionSelectByTicket(ticket);      
         if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL 
         && PositionGetString(POSITION_SYMBOL) == Charts[chartindex].CurrentSymbol )
            {
            OwnPositions++;
            }
         }
       int tryes = 0;
       while (OwnPositions > 0 && tryes < 5)
         {
         for ( int i=0; i<PositionsTotal(); i++ )
            {
            ticket=PositionGetTicket(i);
            ord=PositionSelectByTicket(ticket);      
            if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL 
            && PositionGetString(POSITION_SYMBOL) == Charts[chartindex].CurrentSymbol )
               {
               bool rez = m_trade.PositionClose(ticket);
               tryes++;
               break;
               }
            }
         
         OwnPositions=0;   
         for ( int i=0; i<PositionsTotal(); i++ )
            {
            ticket=PositionGetTicket(i);
            ord=PositionSelectByTicket(ticket);      
            if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL 
            && PositionGetString(POSITION_SYMBOL) == Charts[chartindex].CurrentSymbol )
               {
               OwnPositions++;
               }
            }                      
         }
      if (OwnPositions == 0)
         {
         CloseCycleProcessing();
         }
      }
      
   void CloseBuyF()
      {
      ulong ticket;
      bool ord;
  
      int OwnPositions=0;
      for ( int i=0; i<PositionsTotal(); i++ )
         {
         ticket=PositionGetTicket(i);
         ord=PositionSelectByTicket(ticket);      
         if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY 
         && PositionGetString(POSITION_SYMBOL) == Charts[chartindex].CurrentSymbol )
            {
            OwnPositions++;
            }
         }

       int tryes = 0;
       while (OwnPositions > 0 && tryes < 5)
         {
         for ( int i=0; i<PositionsTotal(); i++ )
            {
            ticket=PositionGetTicket(i);
            ord=PositionSelectByTicket(ticket);      
            if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY 
            && PositionGetString(POSITION_SYMBOL) == Charts[chartindex].CurrentSymbol )
               {
               bool rez = m_trade.PositionClose(ticket);
               tryes++;
               break;
               }
            }
            
         OwnPositions=0;
         for ( int i=0; i<PositionsTotal(); i++ )
            {
            ticket=PositionGetTicket(i);
            ord=PositionSelectByTicket(ticket);      
            if ( ord && PositionGetInteger(POSITION_MAGIC) == MagicF && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY 
            && PositionGetString(POSITION_SYMBOL) == Charts[chartindex].CurrentSymbol )
               {
               OwnPositions++;
               }
            }                      
         }
      if (OwnPositions == 0)
         {
         CloseCycleProcessing();
         }         
      }        
   /////////////////////////////////
      
   bool bOurMagic(ulong ticket,int magiccount)//whether the magic number of the current deal matches one of the possible magic numbers of our robot
      {
      int MagicT[];
      ArrayResize(MagicT,magiccount);
      for ( int i=0; i<magiccount; i++ )
         {
         MagicT[i]=MagicE+i;
         }
      for ( int i=0; i<ArraySize(MagicT); i++ )
         {
         if ( HistoryDealGetInteger(ticket,DEAL_MAGIC) == MagicT[i] ) return true;
         }
      return false;
      }
   };
double BotInstance::K0 = 0;
BotInstance *Bots[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
  CreateCharts();//create virtual charts
  CreateInstances();//create virtual robots
  if (bInterface) CreateSimpleInterface();//create the interface  
  return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  DeleteSimpleInterface();//remove the interface  
  //clear dynamic memory
  for (int j = 0; j < ArraySize(Charts); j++) delete Charts[j];
  for (int j = 0; j < ArraySize(Bots); j++) delete Bots[j];
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  AllChartsTick();//generate a tick on each virtual chart
  AllBotsTick();//generate a tick on each virtual bot
  if (bInterface) UpdateStatus();//update the interface status
  }

//////////////////////////////////////Interface
bool bInterface=true;//Interface

////of the function creating a rectangle, text, button***********************
//create a rectangle border
bool RectLabelCreate(
const long chart_ID=0, // chart ID 
const string name="RectLabel", // label name 
const int sub_window=0, // subwindow number 
const int x=0, // X coordinate 
const int y=0, // Y coordinate 
const int width=50, // width 
const int height=18, // height 
const color back_clr=C'236,233,216', // background color 
const ENUM_BORDER_TYPE border=BORDER_SUNKEN, // const border type 
ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER, // chart corner for anchoring 
const color clr=clrRed, // flat border color (Flat) 
const ENUM_LINE_STYLE style=STYLE_SOLID, // flat border style 
const int line_width=1, // flat border width 
const bool back=false, // const in the background 
bool selection=false, // select to move 
const bool hidden=true, // hidden in the list of objects 
const long z_order=0) // priority for mouse click 
{ 
//--- reset the error value 
ResetLastError(); 
//--- create a rectangle label 
if(!ObjectCreate(chart_ID,name,OBJ_RECTANGLE_LABEL,sub_window,0,0)) 
   { 
   Print(__FUNCTION__, ": failed to create a rectangle label! Error code = ",GetLastError()); 
   return(false); 
   } 
//--- set label coordinates 
ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x); 
ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y); 
//--- set label size 
ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width); 
ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height); 
//--- set the background color 
ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr); 
//--- set border type 
ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_TYPE,border); 
//--- set the chart's corner, relative to which point coordinates are defined 
ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner); 
//--- set flat border color (in Flat mode) 
ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr); 
//--- set flat border line style 
ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style); 
//--- set flat border width 
ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,line_width); 
//--- display in the foreground (false) or background (true) 
ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back); 
//--- enable (true) or disable (false) the mode of moving the label by mouse 
ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection); 
ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection); 
//--- hide (true) or display (false) graphical object name in the object list 
ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden); 
//--- set the priority for receiving the event of a mouse click on the chart 
ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order); 
//--- successful execution 
return(true); 
}

//create text
bool LabelCreate(const long              chart_ID=0,               // chart ID
                 const string            name="Label",             // label name
                 const int               sub_window=0,             // subwindow number
                 const int               x=0,                      // X coordinate
                 const int               y=0,                      // Y coordinate
                 const ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                 const string            text="Label",             // text
                 const string            font="Arial",             // font
                 const int               font_size=10,             // font size
                 const color             clr=clrRed,               // color
                 const double            angle=0.0,                // text angle
                 const ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER, // anchor type
                 const bool              back=false,               // in the background
                 const bool              selection=false,          // select to move
                 const bool              hidden=true,              // hidden in the list of objects
                 const long              z_order=0)                // priority for mouse click
  {
//--- reset the error value
   ResetLastError();
//--- create a text label
   if(!ObjectCreate(chart_ID,name,OBJ_LABEL,sub_window,0,0))
     {
      Print(__FUNCTION__,
            ": failed to create the text label! Error code = ",GetLastError());
      return(false);
     }
//--- set label coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set the text
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
//--- set the text font
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
//--- set font size
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
//--- set the text angle
   ObjectSetDouble(chart_ID,name,OBJPROP_ANGLE,angle);
//--- set anchor type
   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor);
//--- set the color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the label by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click on the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }

//create button
bool ButtonCreate(
const long chart_ID=0,
// chart ID 
const string name="Button", 
// button name 
const int sub_window=0, 
// subwindow number 
const int x=0, 
// X coordinate 
const int y=0, 
// Y coordinate 
const int width=50, 
// button width 
const int height=18, 
// button height 
const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER, 
// chart corner to position the label 
const string text="Button", 
// text 
const string font="Arial", 
// font 
const int font_size=10, 
// font size 
const color clr=clrBlack, 
// text color 
const color back_clr=C'236,233,216', 
// background color 
const color border_clr=clrNONE, 
// border color 
const bool state=false, 
// pressed/released 
const bool back=false, 
// on the background 
const bool selection=false, 
// select to move 
const bool hidden=true, 
// hidden in the list of objects 
const long z_order=0) // priority for mouse click 
{ 
//--- reset the error value 
ResetLastError(); 
//--- create a button 
if(!ObjectCreate(chart_ID,name,OBJ_BUTTON,sub_window,0,0)) 
   { 
   Print(__FUNCTION__, ": failed to create a button! Error code = ",GetLastError()); 
   return(false); 
   } 
//--- set button coordinates 
ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x); 
ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y); 
//--- set button size 
ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width); 
ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height); 
//--- set the chart's corner, relative to which point coordinates are defined 
ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner); 
//--- set the text 
ObjectSetString(chart_ID,name,OBJPROP_TEXT,text); 
//--- set the text font 
ObjectSetString(chart_ID,name,OBJPROP_FONT,font); 
//--- set font size 
ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size); 
//--- set the text color 
ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr); 
//--- set the background color 
ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr); 
//--- set the border color 
ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_COLOR,border_clr); 
//--- display in the foreground (false) or background (true) 
ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back); 
//--- switch the button to the set condition 
ObjectSetInteger(chart_ID,name,OBJPROP_STATE,state); 
//--- enable (true) or disable (false) the mode of moving the button by mouse 
ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection); 
ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection); 
//--- hide (true) or display (false) graphical object name in the object list 
ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden); 
//--- set the priority for receiving the event of a mouse click on the chart 
ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order); 
//--- successful execution 
return(true); 
}
////end of description of the function creating a rectangle, text, button*********************** 
 
 
//Names of future interface objects
string OwnObjectNames[] = {
"template-BorderPanel",//RectLabel
"template-MainPanel",//RectLabel
"template-Name",//Label
"template-Symbols",//Label ** new element
"template-Balance",//Label
"template-Equity",//Label
"template-Profit",//Label
"template-Broker",//Label
"template-Leverage",//Label
"template-BuyPositions",//Label
"template-SellPositions",//Label
"template-CurrentUnitsBuy",//Label
"template-CurrentUnitsSell",//Label
"template-UNSIGNED1",//UNSIGNED1
"template-UNSIGNED2",//UNSIGNED2
"template-UNSIGNED3",//UNSIGNED3
"template-CloseOwn",//Button
"template-CloseAll",//Button
"template-Line-Divider1",//RectLabel separator 1
"template-Line-Divider2",//RectLabel separator 2
"template-Line-Divider3",//RectLabel separator 3
"template-Line-Divider4"//RectLabel separator 4
};

void UpdateStatus()//update interface state
   {
   string TempText="Instruments-timeframes : ";
   TempText+=IntegerToString(ArraySize(CN));//number of symbol-timeframe pairs
   ObjectSetString(0,OwnObjectNames[3],OBJPROP_TEXT,TempText);
   TempText="Balance : ";
   TempText+=DoubleToString(NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE),2),2);
   ObjectSetString(0,OwnObjectNames[4],OBJPROP_TEXT,TempText);
   TempText="Equity : ";
   TempText+=DoubleToString(NormalizeDouble(AccountInfoDouble(ACCOUNT_EQUITY),2),2);
   ObjectSetString(0,OwnObjectNames[5],OBJPROP_TEXT,TempText);
   TempText="Leverage : 1/";
   TempText+=DoubleToString(AccountInfoInteger(ACCOUNT_LEVERAGE),0);
   ObjectSetString(0,OwnObjectNames[8],OBJPROP_TEXT,TempText);
   TempText="Broker : ";
   TempText+=AccountInfoString(ACCOUNT_COMPANY);
   ObjectSetString(0,OwnObjectNames[7],OBJPROP_TEXT,TempText);
   ///////////////////////////
   TempText="Buy positions : ";
   TempText+=DoubleToString(NormalizeDouble(CalculateBuyQuantity(),0),0);   
   ObjectSetString(0,OwnObjectNames[9],OBJPROP_TEXT,TempText);
   TempText="Sell positions : ";
   TempText+=DoubleToString(NormalizeDouble(CalculateSellQuantity(),0),0);      
   ObjectSetString(0,OwnObjectNames[10],OBJPROP_TEXT,TempText);
   TempText="Buy lots : ";
   TempText+=DoubleToString(NormalizeDouble(CalculateBuyLots(),3),3);   
   ObjectSetString(0,OwnObjectNames[11],OBJPROP_TEXT,TempText);
   TempText="Sell lots : ";
   TempText+=DoubleToString(NormalizeDouble(CalculateSellLots(),3),3);   
   ObjectSetString(0,OwnObjectNames[12],OBJPROP_TEXT,TempText);
   TempText="Profit : ";
   TempText+=DoubleToString(NormalizeDouble(AccountInfoDouble(ACCOUNT_EQUITY)-AccountInfoDouble(ACCOUNT_BALANCE),2),2);
   ObjectSetString(0,OwnObjectNames[6],OBJPROP_TEXT,TempText);
   ////////////////////////////
   //TempText="UNSIGNED1 : ";
   //TempText+=DoubleToString(NormalizeDouble(0.0,2),2);
   //ObjectSetString(0,OwnObjectNames[13],OBJPROP_TEXT,TempText);
   //TempText="UNSIGNED2 : ";
   //TempText+=DoubleToString(NormalizeDouble(0.0,2),2);
   //ObjectSetString(0,OwnObjectNames[14],OBJPROP_TEXT,TempText);
   //TempText="UNSIGNED3 : ";
   //TempText+=DoubleToString(NormalizeDouble(0.0,2),2);
   //ObjectSetString(0,OwnObjectNames[15],OBJPROP_TEXT,TempText);
   ///////////////////////////
         
   }

bool bOurMagic0(long magic1)//whether the magic number of the current deal matches one of the possible magic numbers of our robot
   {
   int MagicT[];
   ArrayResize(MagicT,ArraySize(S));
   for ( int i=0; i<ArraySize(MagicT); i++ )
      {
      MagicT[i]=MagicE+i;
      }
   for ( int i=0; i<ArraySize(MagicT); i++ )
      {
      if ( (int)magic1 == MagicT[i] ) return true;
      }
   return false;
   } 

double CalculateBuyLots()//calculate buy lots
   {
   double Lots=0;
   bool ord;
   ulong ticket;
   for ( int i=0; i<PositionsTotal(); i++ )
      {
      ticket=PositionGetTicket(i);
      ord=PositionSelectByTicket(ticket);
      if ( ord && bOurMagic0(PositionGetInteger(POSITION_MAGIC)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY )
         {
         Lots+=PositionGetDouble(POSITION_VOLUME);
         }
      }
   return Lots;   
   }
   
double CalculateSellLots()//calculate sell lots
   {
   double Lots=0;
   bool ord;
   ulong ticket;
   for ( int i=0; i<PositionsTotal(); i++ )
      {
      ticket=PositionGetTicket(i);
      ord=PositionSelectByTicket(ticket);
      if ( ord && bOurMagic0(PositionGetInteger(POSITION_MAGIC)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL )
         {
         Lots+=PositionGetDouble(POSITION_VOLUME);
         }
      }
   return Lots;
   }
   
double CalculateBuyQuantity()//count buy entries
   {
   double Positions=0;
   bool ord;
   ulong ticket;
   for ( int i=0; i<PositionsTotal(); i++ )
      {
      ticket=PositionGetTicket(i);
      ord=PositionSelectByTicket(ticket);
      if ( ord && bOurMagic0(PositionGetInteger(POSITION_MAGIC)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY )
         {
         Positions++;
         }
      }
   return Positions;   
   }
   
double CalculateSellQuantity()//count sell entries
   {
   double Positions=0;
   bool ord;
   ulong ticket;
   for ( int i=0; i<PositionsTotal(); i++ )
      {
      ticket=PositionGetTicket(i);
      ord=PositionSelectByTicket(ticket);
      if ( ord && bOurMagic0(PositionGetInteger(POSITION_MAGIC)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL )
         {
         Positions++;
         }
      }
   return Positions;
   }        

void CloseAllI(int magic0)//close all
   {
   bool ord;
   ulong Tickets[];
   int TicketsTotal=0;
   int TicketNumCurrent=0;
   ulong ticket;
   
   for ( int i=0; i<PositionsTotal(); i++ )
      {
      ticket=PositionGetTicket(i);
      ord=PositionSelectByTicket(ticket);      
                         
      if ( ord && ( bOurMagic0(PositionGetInteger(POSITION_MAGIC)) || magic0 == -1 ) )
         {
         TicketsTotal=TicketsTotal+1;
         }
      }
   ArrayResize(Tickets,TicketsTotal);
         
   for ( int i=0; i<PositionsTotal(); i++ )
      {
      ticket=PositionGetTicket(i);
      ord=PositionSelectByTicket(ticket); 
                         
      if ( ord && ( bOurMagic0(PositionGetInteger(POSITION_MAGIC)) || magic0 == -1 ) && TicketNumCurrent < TicketsTotal )
         {
         Tickets[TicketNumCurrent]=ticket;
         TicketNumCurrent=TicketNumCurrent+1;
         }
      }
      
   for ( int i=0; i<TicketsTotal; i++ )
      {
      m_trade.PositionClose(Tickets[i]);       
      }                     
   }

void CreateSimpleInterface()//create a simple interface
   {
   ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER;//position all elements in the left corner
   int x=5;//offset along X;
   int y=15;//offset along Y;
   int Width = 280;//width 
   int Height = 330;//height
   int Border = 5;//border
   
   RectLabelCreate(0,OwnObjectNames[0],0,x,y,Width+2*Border,Height+2*Border,clrRed,BORDER_RAISED,corner,clrOrchid,STYLE_SOLID,3,false,false,true,0);//border
   RectLabelCreate(0,OwnObjectNames[1],0,x+Border,y+Border,Width,Height,clrCoral,BORDER_RAISED,corner,clrOrchid,STYLE_SOLID,3,false,false,true,0);//main panel
   //text elements
   LabelCreate(0,OwnObjectNames[2],0,x+Border+21,y+Border+4,corner,"   AWAITER MULTI CHARTS BOT","Arial",11,clrWhite,0.0);//EA name
   //
   RectLabelCreate(0,OwnObjectNames[18],0,x+Border,y+Border+25,Width,5,clrWhite,BORDER_RAISED,corner,clrOrchid,STYLE_SOLID,0,false,false,true,0);//first separator   
   //text elements
   LabelCreate(0,OwnObjectNames[3],0,x+Border+2,y+17+Border+20*1,corner,"Instruments-timeframes : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//balance
   LabelCreate(0,OwnObjectNames[4],0,x+Border+2,y+17+Border+20*2,corner,"Balance : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//equity
   LabelCreate(0,OwnObjectNames[7],0,x+Border+2,y+17+Border+20*3,corner,"Broker : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//leverage
   LabelCreate(0,OwnObjectNames[6],0,x+Border+2,y+17+Border+20*4,corner,"Profit : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//broker
   LabelCreate(0,OwnObjectNames[8],0,x+Border+2,y+17+Border+20*5,corner,"Leverage : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//spread           
   //
   RectLabelCreate(0,OwnObjectNames[19],0,x+Border,y+Border+25+100,Width,5,clrWhite,BORDER_RAISED,corner,clrOrchid,STYLE_SOLID,0,false,false,true,0);//second separator   
   //text elements
   LabelCreate(0,OwnObjectNames[9],0,x+Border+2,y+17+Border+20*5+20,corner,"Buy positions : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//buy positions
   LabelCreate(0,OwnObjectNames[10],0,x+Border+2,y+17+Border+20*5+20*2,corner,"Sell positions : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//sell positions
   LabelCreate(0,OwnObjectNames[11],0,x+Border+2,y+17+Border+20*5+20*3,corner,"Buy lots : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//volume of buy positions
   LabelCreate(0,OwnObjectNames[12],0,x+Border+2,y+17+Border+20*5+20*4,corner,"Sell lots : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//volume of sell positions
   LabelCreate(0,OwnObjectNames[5],0,x+Border+2,y+17+Border+20*5+20*5,corner,"Equity : ","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//profit of floating positions       
   //
   RectLabelCreate(0,OwnObjectNames[20],0,x+Border,y+Border+25+100+100,Width,5,clrWhite,BORDER_RAISED,corner,clrOrchid,STYLE_SOLID,0,false,false,true,0);//third separator
   //text elements
   //LabelCreate(0,OwnObjectNames[13],0,x+Border+2,y+17+Border+20*5+20*5+23,corner,"","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//UNSIGNED1
   //LabelCreate(0,OwnObjectNames[14],0,x+Border+2,y+17+Border+20*5+20*5+23+20*1,corner,"","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//UNSIGNED1
   //LabelCreate(0,OwnObjectNames[15],0,x+Border+2,y+17+Border+20*5+20*5+23+20*2,corner,"","Arial",11,clrWhite,0.0,ANCHOR_LEFT);//UNSIGNED2
   //   
   RectLabelCreate(0,OwnObjectNames[21],0,x+Border,y+Border+25+100+95+72,Width,5,clrWhite,BORDER_RAISED,corner,clrOrchid,STYLE_SOLID,0,false,false,true,0);//fourth separator
   ButtonCreate(0,OwnObjectNames[16],0,x+Border+5,y+17+Border+20*5+20*5+23+20*2+20,130,25,corner,"Close own orders","Arial",11,clrWhite,clrCrimson,clrNONE,false,false,false,true,0);
   ButtonCreate(0,OwnObjectNames[17],0,x+Border+5+140,y+17+Border+20*5+20*5+23+20*2+20,130,25,corner,"Close all orders","Arial",11,clrWhite,clrBlueViolet,clrNONE,false,false,false,true,0);
   }

 
void ButtonsCheck(string sparam0)//check buttons, unpress and close relevant orders
   {
   if ( sparam0 == OwnObjectNames[16] )//close own
      {
      CloseAllI(0);
      }
      
   if ( sparam0 == OwnObjectNames[17] )//close all
      {
      CloseAllI(-1);
      }         
   
   if ( sparam0 == OwnObjectNames[16] || sparam0 == OwnObjectNames[17] )
      {
      if ( ObjectGetInteger(0,sparam0,OBJPROP_STATE,0) )
         {
         ObjectSetInteger(0,OwnObjectNames[16],OBJPROP_STATE,false);
         ObjectSetInteger(0,OwnObjectNames[17],OBJPROP_STATE,false);
         }      
      }
   } 
 
void DeleteSimpleInterface()//delete all elements of the interface
   {
   ObjectsDeleteAll(0,"template");
   }

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
  if (id == CHARTEVENT_OBJECT_CLICK )//
     {
     ButtonsCheck(sparam);
     }
  }
   

//////////////////////////////////////
