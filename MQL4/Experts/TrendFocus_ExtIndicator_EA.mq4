//+------------------------------------------------------------------+
//| TrendFocus_ExtIndicator_EA.mq4                                    |
//| Standalone EA that trades signals read directly from the          |
//| compiled TrendFocus.ex4 custom indicator via iCustom() -- it does |
//| NOT contain any of the Pine-derived strategy logic used by        |
//| TrendFocus_MultiStrategy_EA.mq4. This is a separate product.      |
//|                                                                    |
//| TrendFocus.ex4 is a compiled binary -- its internal buffer layout |
//| is not known, so buffer indices and signal interpretation are all |
//| Inputs-tab settings below (defaults: buffer 0 = buy, buffer 1 =   |
//| sell). Adjust InpBuyBufferIndex/InpSellBufferIndex if your build  |
//| of the indicator uses different buffers.                          |
//|                                                                    |
//| No break-even management. SL/TP are fixed percent only:           |
//| SL 0.5% / TP 1% by default (Inputs tab > Risk / Trade Management).|
//+------------------------------------------------------------------+
#property copyright "TrendFocus Ext-Indicator EA"
#property strict

#include <TrendFocusCore.mqh>   // reuses ENUM_POS_SIZE_MODE / CalcLots / session helpers

//====================================================================
// INPUTS
//====================================================================
input group "==== Indicator Signal Source ===="
input string           InpIndicatorName      = "TrendFocus";  // must match the compiled indicator's file name (no .ex4)
input ENUM_TIMEFRAMES  InpSignalTF           = PERIOD_CURRENT;

enum ENUM_SIGNAL_MODE { SIGNAL_TWO_BUFFER, SIGNAL_SINGLE_BUFFER };
input ENUM_SIGNAL_MODE InpSignalMode         = SIGNAL_TWO_BUFFER;
input int               InpBuyBufferIndex     = 0;   // used when mode = Two Buffer
input int               InpSellBufferIndex    = 1;   // used when mode = Two Buffer
input int               InpSingleBufferIndex  = 0;   // used when mode = Single Buffer (>0 buy, <0 sell)
input int               InpSignalShift        = 1;    // 1 = last CLOSED bar (non-repainting); 0 = live bar
input bool              InpRequireNewSignalBar= true;  // only evaluate once per new InpSignalTF bar

input group "==== Risk / Trade Management ===="
input double InpSLPercent = 0.5;   // fixed stop-loss, % of entry price
input double InpTPPercent = 1.0;   // fixed take-profit, % of entry price

input group "==== Position Sizing ===="
input ENUM_POS_SIZE_MODE InpPosSizeMode = SIZE_RISK_PERCENT;
input double              InpFixedLots   = 0.01;
input double              InpFixedMoney  = 1000;
input double              InpRiskPercent = 1.0;

input group "==== Trade Controls ===="
input bool   InpTradingEnabled        = true;
input bool   InpCloseOnOppositeSignal = false;
input int    InpMaxOpenTrades         = 1;
input int    InpMaxTradesPerDay       = 0;      // 0 = unlimited
input double InpMaxDailyLossPercent   = 0;      // 0 = disabled
input int    InpMaxSpreadPoints       = 0;      // 0 = no limit
input int    InpSlippagePoints        = 3;
input int    InpMagicNumber           = 771000;
input string InpOrderCommentPrefix    = "TFExt";

input group "==== Session Filter ===="
input bool                 InpEnableSession          = false;
input ENUM_SESSION_PRESET  InpSessionPreset          = SESSION_LONDON;
input int                  InpCustomSessionStartHour = 8;
input int                  InpCustomSessionStartMin  = 0;
input int                  InpCustomSessionEndHour   = 17;
input int                  InpCustomSessionEndMin    = 0;
input int                  InpBrokerGMTOffset        = 0;

input group "==== Notifications ===="
input bool InpEnablePushNotify   = false;

//====================================================================
// STATE
//====================================================================
int      g_tradesToday=0;
datetime g_lastDayStamp=0;
double   g_dayStartEquity=0;
datetime g_lastBarTime=0;

int OnInit()
{
   g_dayStartEquity = AccountEquity();
   g_lastDayStamp = TimeCurrent() - (TimeCurrent()%86400);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

//====================================================================
// HELPERS
//====================================================================
int CountOpenOrders()
{
   int c=0;
   for(int i=0;i<OrdersTotal();i++)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==InpMagicNumber)
         c++;
   return c;
}

void CloseOppositeOrders(int newDir)
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber) continue;
      if(newDir==1 && OrderType()==OP_SELL)
         OrderClose(OrderTicket(), OrderLots(), MarketInfo(Symbol(),MODE_ASK), InpSlippagePoints, clrOrange);
      else if(newDir==-1 && OrderType()==OP_BUY)
         OrderClose(OrderTicket(), OrderLots(), MarketInfo(Symbol(),MODE_BID), InpSlippagePoints, clrOrange);
   }
}

void CalcFixedPctSLTP(int dir, double entryPx, double &slPx, double &tpPx)
{
   if(dir==1) { slPx=entryPx*(1-InpSLPercent/100.0); tpPx=entryPx*(1+InpTPPercent/100.0); }
   else       { slPx=entryPx*(1+InpSLPercent/100.0); tpPx=entryPx*(1-InpTPPercent/100.0); }
}

// Returns true if a signal is present this call; dir is set to 1 (buy) or -1 (sell).
bool GetSignal(int &dir)
{
   dir=0;
   if(InpSignalMode==SIGNAL_TWO_BUFFER)
   {
      double buyVal  = iCustom(Symbol(), InpSignalTF, InpIndicatorName, InpBuyBufferIndex, InpSignalShift);
      double sellVal = iCustom(Symbol(), InpSignalTF, InpIndicatorName, InpSellBufferIndex, InpSignalShift);
      bool buySig  = (buyVal !=EMPTY_VALUE && buyVal !=0);
      bool sellSig = (sellVal!=EMPTY_VALUE && sellVal!=0);
      if(buySig && !sellSig) dir=1;
      else if(sellSig && !buySig) dir=-1;
   }
   else
   {
      double v = iCustom(Symbol(), InpSignalTF, InpIndicatorName, InpSingleBufferIndex, InpSignalShift);
      if(v!=EMPTY_VALUE)
      {
         if(v>0) dir=1;
         else if(v<0) dir=-1;
      }
   }
   return dir!=0;
}

bool PlaceOrder(int dir, double lots, double slPx, double tpPx)
{
   string symbol=Symbol();
   int cmd = (dir==1) ? OP_BUY : OP_SELL;
   double price = (dir==1) ? MarketInfo(symbol,MODE_ASK) : MarketInfo(symbol,MODE_BID);
   int dg = (int)MarketInfo(symbol,MODE_DIGITS);
   int ticket = OrderSend(symbol, cmd, lots, price, InpSlippagePoints,
                           NormalizeDouble(slPx,dg), NormalizeDouble(tpPx,dg),
                           InpOrderCommentPrefix, InpMagicNumber, 0, (dir==1?clrLime:clrRed));
   if(ticket<0)
   {
      Print("OrderSend failed err="+IntegerToString(GetLastError()));
      return false;
   }
   string msg = StringFormat("%s %s filled, lots=%s entry=%s SL=%s TP=%s ticket=%d",
                  InpOrderCommentPrefix, (dir==1?"BUY":"SELL"), DoubleToString(lots,2),
                  DoubleToString(price,dg), DoubleToString(slPx,dg), DoubleToString(tpPx,dg), ticket);
   Print(msg);
   if(InpEnablePushNotify) SendNotification(msg);
   return true;
}

//====================================================================
// MAIN LOOP
//====================================================================
void OnTick()
{
   datetime dayStamp = TimeCurrent() - (TimeCurrent()%86400);
   if(dayStamp != g_lastDayStamp)
   {
      g_lastDayStamp = dayStamp;
      g_tradesToday = 0;
      g_dayStartEquity = AccountEquity();
   }

   datetime t0 = iTime(Symbol(), InpSignalTF, 0);
   bool newBar = (t0 != g_lastBarTime);
   if(newBar) g_lastBarTime=t0;

   if(!InpTradingEnabled) return;
   if(InpRequireNewSignalBar && !newBar) return;

   int dir;
   if(!GetSignal(dir)) return;

   if(InpCloseOnOppositeSignal) CloseOppositeOrders(dir);

   bool dailyLossHalted = (InpMaxDailyLossPercent>0) &&
                           (AccountEquity() <= g_dayStartEquity*(1-InpMaxDailyLossPercent/100.0));
   if(dailyLossHalted) return;

   int startH,startM,endH,endM;
   ResolveSessionPreset(InpSessionPreset, InpCustomSessionStartHour, InpCustomSessionStartMin,
                        InpCustomSessionEndHour, InpCustomSessionEndMin, startH,startM,endH,endM);
   if(!InSession(InpEnableSession, startH,startM,endH,endM, InpBrokerGMTOffset)) return;

   if(InpMaxTradesPerDay>0 && g_tradesToday>=InpMaxTradesPerDay) return;
   if(CountOpenOrders() >= InpMaxOpenTrades) return;

   double spreadPts = MarketInfo(Symbol(), MODE_SPREAD);
   if(InpMaxSpreadPoints>0 && spreadPts>InpMaxSpreadPoints) return;

   double entryPx = (dir==1) ? MarketInfo(Symbol(),MODE_ASK) : MarketInfo(Symbol(),MODE_BID);
   double slPx, tpPx;
   CalcFixedPctSLTP(dir, entryPx, slPx, tpPx);

   double lots = CalcLots(Symbol(), InpPosSizeMode, InpFixedLots, InpFixedMoney, InpRiskPercent, entryPx, slPx);
   if(lots<=0) { Print("Entry skipped, computed lot size <= 0"); return; }

   if(PlaceOrder(dir, lots, slPx, tpPx)) g_tradesToday++;
}
//+------------------------------------------------------------------+
