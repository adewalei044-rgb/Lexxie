//+------------------------------------------------------------------+
//| SweepTrendOBFVG_EA.mq4                                            |
//| Automated execution of the 4-strategy "Multi-Strategy: Sweep      |
//| Reversal & Trend Continuation (OB/FVG)" signal engine (Sweep      |
//| Reversal, Trend Continuation, RSI Divergence, Bollinger Bands).   |
//| Places real orders with structural or fixed-% SL/TP, manages      |
//| break-even, and enforces real risk controls: risk-based position  |
//| sizing, max daily loss cutoff, max open trades, max trades/day,   |
//| session filter and spread guard.                                  |
//|                                                                    |
//| Pairs with SweepTrendOBFVG_Indicator.mq4 for visuals -- run both  |
//| on the same chart/symbol for signals you can see AND trade.       |
//+------------------------------------------------------------------+
#property copyright "Sweep Reversal & Trend Continuation (OB/FVG) MT4 Port"
#property strict

#include <SweepTrendOBFVG_Core.mqh>

//====================================================================
// INPUTS -- signal customization (identical to the companion indicator)
//====================================================================
input group "==== Strategy Toggles ===="
input bool InpEnableS1 = true;   // Enable Strategy 1: Sweep Reversal
input bool InpEnableS2 = true;   // Enable Strategy 2: Trend Continuation
input bool InpEnableS3 = true;   // Enable Strategy 3: RSI Divergence
input bool InpEnableS4 = true;   // Enable Strategy 4: Bollinger Bands

input group "==== Strategy 1: Sweep Reversal ===="
input bool             InpS1_4H_On            = true;
input ENUM_TIMEFRAMES  InpS1_4H_TF            = PERIOD_H4;
input bool             InpS1_5M_On            = true;
input ENUM_TIMEFRAMES  InpS1_5M_TF            = PERIOD_M5;
input bool             InpS1_1H_On            = false;
input ENUM_TIMEFRAMES  InpS1_1H_TF            = PERIOD_H1;
input bool             InpS1_1M_On            = false;
input ENUM_TIMEFRAMES  InpS1_1M_TF            = PERIOD_M1;
input bool             InpS1_RequireFullClose = true;
input bool             InpS1_UseOB            = true;
input bool             InpS1_UseFVG           = true;
input int              InpS1_MaxWaitBars      = 200;
input bool             InpS1_OneSignalPerSweep= true;

input group "==== Strategy 2: Trend Continuation ===="
input bool              InpS2_1H_On            = true;
input ENUM_TIMEFRAMES   InpS2_1H_TF            = PERIOD_H1;
input bool              InpS2_1M_On            = true;
input ENUM_TIMEFRAMES   InpS2_1M_TF            = PERIOD_M1;
input bool              InpS2_4H_On            = false;
input ENUM_TIMEFRAMES   InpS2_4H_TF            = PERIOD_H4;
input bool              InpS2_5M_On            = false;
input ENUM_TIMEFRAMES   InpS2_5M_TF            = PERIOD_M5;
input ENUM_TREND_METHOD InpS2_TrendMethod      = TREND_AUTO_EMA;
input int                InpS2_EmaLen           = 50;
input int                InpS2_SwingN            = 3;
input ENUM_MANUAL_BIAS   InpS2_ManualBias        = BIAS_BULLISH;
input bool               InpS2_RequireFullClose  = true;
input int                InpS2_MaxWaitBars       = 200;
input bool               InpS2_OneSignalPerCont  = true;

input group "==== Strategy 3: RSI Divergence ===="
input ENUM_TF_MODE        InpS3_TFMode      = TFMODE_SINGLE;
input ENUM_TIMEFRAMES     InpS3_DivTF       = PERIOD_M15;
input ENUM_TIMEFRAMES     InpS3_EntryTF     = PERIOD_M1;
input int                 InpS3_RsiLen      = 14;
input int                 InpS3_PivotLeft   = 5;
input int                 InpS3_PivotRight  = 5;
input int                 InpS3_MaxDivBars  = 60;
input ENUM_DIV_ENTRY_MODE InpS3_EntryMode   = DIVMODE_ALONE;
input bool                InpS3_UseOB       = true;
input bool                InpS3_UseFVG      = true;
input int                 InpS3_MaxWaitBars = 200;
input bool                InpS3_OneSignalPerDiv = true;

input group "==== Strategy 4: Bollinger Bands ===="
input ENUM_TF_MODE         InpS4_TFMode     = TFMODE_SINGLE;
input ENUM_TIMEFRAMES      InpS4_BBTF       = PERIOD_M15;
input ENUM_TIMEFRAMES      InpS4_EntryTF    = PERIOD_M1;
input int                  InpS4_BBLen      = 20;
input double                InpS4_BBMult     = 2.0;
input ENUM_BB_SIGNAL_MODE   InpS4_BBMode     = BB_MEAN_REVERSION;
input ENUM_BB_ENTRY_MODE    InpS4_EntryMode  = BBMODE_ALONE;
input bool                  InpS4_UseOB      = true;
input bool                  InpS4_UseFVG     = true;
input int                   InpS4_MaxWaitBars= 200;
input bool                  InpS4_OneSignalPerBB = true;

input group "==== Signal SL / TP ===="
input double            InpRRMultiple     = 2.0;
input ENUM_SLTP_METHOD  InpSLTPMethod     = SLTP_STRUCTURAL;
input double             InpSLPercent      = 0.5;
input double             InpTPPercent      = 1.0;
input bool               InpEnableBE       = false;
input double             InpBETriggerR     = 1.0;

input group "==== Session Filter ===="
input bool                 InpEnableSession        = false;
input ENUM_SESSION_PRESET  InpSessionPreset        = SESSION_LONDON;
input int                  InpCustomSessionStartHour = 8;
input int                  InpCustomSessionStartMin  = 0;
input int                  InpCustomSessionEndHour   = 17;
input int                  InpCustomSessionEndMin    = 0;
input int                  InpBrokerGMTOffset        = 0;    // hours broker server time is ahead of UTC

//====================================================================
// INPUTS -- real risk management / execution
//====================================================================
input group "==== Risk Management ===="
input bool               InpTradingEnabled     = true;    // master kill switch
input ENUM_POS_SIZE_MODE InpPosSizeMode        = SIZE_RISK_PERCENT;
input double              InpFixedLots          = 0.01;    // used when mode = Fixed Lots
input double              InpFixedMoney         = 1000;    // used when mode = Fixed Money (approx, see CalcLots note)
input double              InpRiskPercent        = 1.0;     // used when mode = Risk % Equity (recommended)
input double              InpMaxDailyLossPercent= 0;       // 0 = disabled; halts NEW entries for the rest of the day
input int                 InpMaxOpenTrades      = 6;       // concurrent trades across all 6 pair-instances
input int                 InpMaxTradesPerDay    = 0;       // 0 = unlimited
input int                 InpMaxSpreadPoints    = 0;       // 0 = no limit
input int                 InpSlippagePoints     = 3;
input int                 InpMagicBase          = 770000;
input string              InpOrderCommentPrefix = "TFMS";

input group "==== Webhook Alerts (optional) ===="
input bool   InpEnableWebhook   = false;
input string InpWebhookURL      = "";  // must be whitelisted in Tools > Options > Expert Advisors > Allow WebRequest
input string InpWebhookTemplate = "{\"symbol\":\"{{symbol}}\",\"side\":\"{{side}}\",\"price\":{{price}},\"sl\":{{sl}},\"tp\":{{tp}},\"break_even\":{{be}}}";

input group "==== Notifications ===="
input bool InpEnablePushNotify = false;

//====================================================================
// PAIR INSTANCES: 0=S1 4H/5M 1=S1 1H/1M 2=S2 1H/1M 3=S2 4H/5M 4=S3 Div 5=S4 BB
//====================================================================
#define PAIR_COUNT 6
PairState g_pairs[PAIR_COUNT];
string    g_tags[PAIR_COUNT] = {"S1 4H/5M","S1 1H/1M","S2 1H/1M","S2 4H/5M","S3 Div","S4 BB"};

int      g_tradesToday=0;
datetime g_lastDayStamp=0;
double   g_dayStartEquity=0;

//====================================================================
// LIFECYCLE
//====================================================================
int OnInit()
{
   for(int i=0;i<PAIR_COUNT;i++)
      InitPairState(g_pairs[i], g_tags[i], InpMagicBase+i);
   g_dayStartEquity = AccountEquity();
   g_lastDayStamp = TimeCurrent() - (TimeCurrent()%86400);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

bool OneSignalFlagFor(int idx)
{
   if(idx==0 || idx==1) return InpS1_OneSignalPerSweep;
   if(idx==2 || idx==3) return InpS2_OneSignalPerCont;
   if(idx==4) return InpS3_OneSignalPerDiv;
   return InpS4_OneSignalPerBB;
}

int OpenTradesCount()
{
   int c=0;
   for(int i=0;i<PAIR_COUNT;i++) if(g_pairs[i].inTrade) c++;
   return c;
}

//====================================================================
// ORDER MANAGEMENT
//====================================================================
void CheckClosedOrder(PairState &st, bool oneSignalFlag)
{
   if(!st.inTrade || st.ticket<0) return;
   if(OrderSelect(st.ticket, SELECT_BY_TICKET))
   {
      if(OrderCloseTime()!=0) ResetPairAfterClose(st, oneSignalFlag);
   }
   else
   {
      ResetPairAfterClose(st, oneSignalFlag);
   }
}

void ManageBreakEven(PairState &st)
{
   if(!st.inTrade || st.ticket<0 || !InpEnableBE || st.beDone) return;
   if(!OrderSelect(st.ticket, SELECT_BY_TICKET)) return;
   if(OrderCloseTime()!=0) return;

   double bid = MarketInfo(OrderSymbol(), MODE_BID);
   double ask = MarketInfo(OrderSymbol(), MODE_ASK);
   bool trigger=false;
   if(st.tradeDir==1  && bid >= st.entryPx + (st.entryPx-st.slPx)*InpBETriggerR) trigger=true;
   if(st.tradeDir==-1 && ask <= st.entryPx - (st.slPx-st.entryPx)*InpBETriggerR) trigger=true;

   if(trigger)
   {
      int dg=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);
      bool ok = OrderModify(st.ticket, OrderOpenPrice(), NormalizeDouble(st.entryPx,dg), OrderTakeProfit(), 0, clrYellow);
      if(ok)
      {
         st.slPx=st.entryPx; st.beDone=true;
         string msg = st.tag+" break-even triggered, stop moved to "+DoubleToString(st.entryPx,dg);
         Print(msg);
         if(InpEnablePushNotify) SendNotification(msg);
         if(InpEnableWebhook) SendWebhookAlert(st, true, 0);
      }
      else
         Print(st.tag+" break-even OrderModify failed err="+IntegerToString(GetLastError()));
   }
}

bool PlaceOrder(PairState &st, string symbol, double lots)
{
   int cmd = (st.tradeDir==1) ? OP_BUY : OP_SELL;
   double price = (st.tradeDir==1) ? MarketInfo(symbol,MODE_ASK) : MarketInfo(symbol,MODE_BID);
   int dg = (int)MarketInfo(symbol,MODE_DIGITS);
   int ticket = OrderSend(symbol, cmd, lots, price, InpSlippagePoints,
                           NormalizeDouble(st.slPx,dg), NormalizeDouble(st.tpPx,dg),
                           InpOrderCommentPrefix+" "+st.tag, st.magic, 0,
                           (st.tradeDir==1?clrLime:clrRed));
   if(ticket<0)
   {
      Print(st.tag+": OrderSend failed err="+IntegerToString(GetLastError()));
      return false;
   }
   st.ticket=ticket;
   return true;
}

void HandleNewEntry(PairState &st, string symbol)
{
   double spreadPts = MarketInfo(symbol, MODE_SPREAD);
   if(InpMaxSpreadPoints>0 && spreadPts>InpMaxSpreadPoints)
   {
      Print(st.tag+": entry skipped, spread too wide ("+DoubleToString(spreadPts,0)+" pts)");
      ResetPairAfterClose(st, true);
      return;
   }

   double lots = CalcLots(symbol, InpPosSizeMode, InpFixedLots, InpFixedMoney, InpRiskPercent, st.entryPx, st.slPx);
   if(lots<=0)
   {
      Print(st.tag+": entry skipped, computed lot size <= 0");
      ResetPairAfterClose(st, true);
      return;
   }

   if(!PlaceOrder(st, symbol, lots))
   {
      ResetPairAfterClose(st, true);
      return;
   }

   g_tradesToday++;
   int dg=(int)MarketInfo(symbol,MODE_DIGITS);
   string dirTxt=(st.tradeDir==1)?"BUY":"SELL";
   string msg = StringFormat("%s %s filled, lots=%s entry=%s SL=%s TP=%s ticket=%d",
                  st.tag, dirTxt, DoubleToString(lots,2), DoubleToString(st.entryPx,dg),
                  DoubleToString(st.slPx,dg), DoubleToString(st.tpPx,dg), st.ticket);
   Print(msg);
   if(InpEnablePushNotify) SendNotification(msg);
   if(InpEnableWebhook) SendWebhookAlert(st, false, lots);
}

void SendWebhookAlert(PairState &st, bool isBE, double lots)
{
   if(!InpEnableWebhook || StringLen(InpWebhookURL)==0) return;
   int dg=(int)MarketInfo(Symbol(),MODE_DIGITS);
   string json = InpWebhookTemplate;
   StringReplace(json, "{{symbol}}", Symbol());
   StringReplace(json, "{{side}}",   (st.tradeDir==1?"buy":"sell"));
   StringReplace(json, "{{price}}",  DoubleToString(st.entryPx,dg));
   StringReplace(json, "{{sl}}",     DoubleToString(st.slPx,dg));
   StringReplace(json, "{{tp}}",     DoubleToString(st.tpPx,dg));
   StringReplace(json, "{{be}}",     isBE?"true":"false");
   StringReplace(json, "{{volume}}", DoubleToString(lots,2));

   char post[]; char result[]; string resultHeaders;
   int n = StringToCharArray(json, post, 0, StringLen(json));
   ArrayResize(post, n>0?n-1:0); // drop trailing null terminator StringToCharArray adds
   int res = WebRequest("POST", InpWebhookURL, "Content-Type: application/json\r\n", 5000, post, result, resultHeaders);
   if(res==-1)
      Print("Webhook failed err="+IntegerToString(GetLastError())+" -- add the URL under Tools > Options > Expert Advisors > Allow WebRequest for listed URL");
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

   // Manage existing trades every tick regardless of the kill switch, so an
   // operator can flip InpTradingEnabled off to stop NEW entries without
   // abandoning break-even/close bookkeeping on trades already open.
   for(int i=0;i<PAIR_COUNT;i++)
   {
      CheckClosedOrder(g_pairs[i], OneSignalFlagFor(i));
      ManageBreakEven(g_pairs[i]);
   }

   if(!InpTradingEnabled) return;

   bool dailyLossHalted = (InpMaxDailyLossPercent>0) &&
                           (AccountEquity() <= g_dayStartEquity*(1-InpMaxDailyLossPercent/100.0));

   int startH,startM,endH,endM;
   ResolveSessionPreset(InpSessionPreset, InpCustomSessionStartHour, InpCustomSessionStartMin,
                        InpCustomSessionEndHour, InpCustomSessionEndMin, startH,startM,endH,endM);
   bool sessionOk = InSession(InpEnableSession, startH,startM,endH,endM, InpBrokerGMTOffset);

   bool canTradeMore = !dailyLossHalted
                     && (InpMaxTradesPerDay<=0 || g_tradesToday<InpMaxTradesPerDay)
                     && (OpenTradesCount() < InpMaxOpenTrades);

   string symbol = Symbol();
   bool je, sd, zf, hb, bt;

   UpdateSweepPair(g_pairs[0], symbol, InpEnableS1 && InpS1_4H_On, InpS1_4H_TF, InpEnableS1 && InpS1_5M_On, InpS1_5M_TF,
      InpS1_RequireFullClose, InpS1_UseOB, InpS1_UseFVG, InpS1_MaxWaitBars, InpS1_OneSignalPerSweep,
      InpRRMultiple, canTradeMore, sessionOk, InpSLTPMethod, InpSLPercent, InpTPPercent,
      InpEnableBE, InpBETriggerR, false, je,sd,zf,hb,bt);
   if(je) HandleNewEntry(g_pairs[0], symbol);

   UpdateSweepPair(g_pairs[1], symbol, InpEnableS1 && InpS1_1H_On, InpS1_1H_TF, InpEnableS1 && InpS1_1M_On, InpS1_1M_TF,
      InpS1_RequireFullClose, InpS1_UseOB, InpS1_UseFVG, InpS1_MaxWaitBars, InpS1_OneSignalPerSweep,
      InpRRMultiple, canTradeMore, sessionOk, InpSLTPMethod, InpSLPercent, InpTPPercent,
      InpEnableBE, InpBETriggerR, false, je,sd,zf,hb,bt);
   if(je) HandleNewEntry(g_pairs[1], symbol);

   UpdateContPair(g_pairs[2], symbol, InpEnableS2 && InpS2_1H_On, InpS2_1H_TF, InpEnableS2 && InpS2_1M_On, InpS2_1M_TF,
      InpS2_TrendMethod, InpS2_EmaLen, InpS2_SwingN, InpS2_ManualBias, InpS2_RequireFullClose,
      InpS2_MaxWaitBars, InpS2_OneSignalPerCont, InpRRMultiple, canTradeMore, sessionOk,
      InpSLTPMethod, InpSLPercent, InpTPPercent, InpEnableBE, InpBETriggerR, false, je,sd,zf,hb,bt);
   if(je) HandleNewEntry(g_pairs[2], symbol);

   UpdateContPair(g_pairs[3], symbol, InpEnableS2 && InpS2_4H_On, InpS2_4H_TF, InpEnableS2 && InpS2_5M_On, InpS2_5M_TF,
      InpS2_TrendMethod, InpS2_EmaLen, InpS2_SwingN, InpS2_ManualBias, InpS2_RequireFullClose,
      InpS2_MaxWaitBars, InpS2_OneSignalPerCont, InpRRMultiple, canTradeMore, sessionOk,
      InpSLTPMethod, InpSLPercent, InpTPPercent, InpEnableBE, InpBETriggerR, false, je,sd,zf,hb,bt);
   if(je) HandleNewEntry(g_pairs[3], symbol);

   UpdateDivPair(g_pairs[4], symbol, InpEnableS3, InpS3_DivTF, InpS3_TFMode, InpS3_EntryTF,
      InpS3_RsiLen, InpS3_PivotLeft, InpS3_PivotRight, InpS3_MaxDivBars, InpS3_EntryMode,
      InpS3_UseOB, InpS3_UseFVG, InpS3_MaxWaitBars, InpS3_OneSignalPerDiv, InpRRMultiple,
      canTradeMore, sessionOk, InpSLTPMethod, InpSLPercent, InpTPPercent, InpEnableBE, InpBETriggerR,
      false, je,sd,zf,hb,bt);
   if(je) HandleNewEntry(g_pairs[4], symbol);

   UpdateBBPair(g_pairs[5], symbol, InpEnableS4, InpS4_BBTF, InpS4_TFMode, InpS4_EntryTF,
      InpS4_BBLen, InpS4_BBMult, InpS4_BBMode, InpS4_EntryMode, InpS4_UseOB, InpS4_UseFVG,
      InpS4_MaxWaitBars, InpS4_OneSignalPerBB, InpRRMultiple, canTradeMore, sessionOk,
      InpSLTPMethod, InpSLPercent, InpTPPercent, InpEnableBE, InpBETriggerR, false, je,sd,zf,hb,bt);
   if(je) HandleNewEntry(g_pairs[5], symbol);
}
//+------------------------------------------------------------------+
