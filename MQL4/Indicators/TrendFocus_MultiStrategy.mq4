//+------------------------------------------------------------------+
//| TrendFocus_MultiStrategy.mq4                                      |
//| Visual signal indicator for the 4-strategy TrendFocus system      |
//| (Sweep Reversal, Trend Continuation, RSI Divergence, Bollinger    |
//| Bands). Draws the same sweep/continuation boxes, OB/FVG zones,    |
//| BUY/SELL labels and SL/TP lines as the source Pine script, and    |
//| fires MT4 alerts/push notifications on each signal.               |
//|                                                                    |
//| This indicator places NO trades -- it is signal/visual only.      |
//| Pair it with TrendFocus_MultiStrategy_EA.mq4 for automated        |
//| execution of the same signals.                                    |
//+------------------------------------------------------------------+
#property copyright "TrendFocus Multi-Strategy Port"
#property strict
#property indicator_chart_window

#include <TrendFocusCore.mqh>

//====================================================================
// INPUTS
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

input group "==== Risk / Trade Management (simulated) ===="
input double            InpRRMultiple     = 2.0;
input ENUM_SLTP_METHOD  InpSLTPMethod     = SLTP_STRUCTURAL;
input double             InpSLPercent      = 0.5;
input double             InpTPPercent      = 1.0;
input bool               InpEnableBE       = false;
input double             InpBETriggerR     = 1.0;
input int                InpMaxTradesPerDay= 0;

input group "==== Session Filter ===="
input bool                 InpEnableSession        = false;
input ENUM_SESSION_PRESET  InpSessionPreset        = SESSION_LONDON;
input int                  InpCustomSessionStartHour = 8;
input int                  InpCustomSessionStartMin  = 0;
input int                  InpCustomSessionEndHour   = 17;
input int                  InpCustomSessionEndMin    = 0;
input int                  InpBrokerGMTOffset        = 0;    // hours broker server time is ahead of UTC

input group "==== Visuals & Alerts ===="
input color InpBullColor        = clrLime;
input color InpBearColor        = clrRed;
input bool  InpShowSLTPLabels   = true;
input bool  InpShowInfoPanel    = true;
input bool  InpEnableAlerts     = true;
input bool  InpEnablePopupAlert = true;
input bool  InpEnablePushNotify = false;

//====================================================================
// PAIR INSTANCES: 0=S1 4H/5M 1=S1 1H/1M 2=S2 1H/1M 3=S2 4H/5M 4=S3 Div 5=S4 BB
//====================================================================
#define PAIR_COUNT 6
PairState g_pairs[PAIR_COUNT];
string    g_tags[PAIR_COUNT] = {"S1 4H/5M","S1 1H/1M","S2 1H/1M","S2 4H/5M","S3 Div","S4 BB"};

int      g_htfBarsProcessed=0, g_signalsDetected=0, g_zonesFound=0, g_entriesTriggered=0;
int      g_tradesToday=0;
datetime g_lastDayStamp=0;
string   g_lastSignalText="(none yet)";

#define OBJ_PREFIX "TFMS_"
#define MAX_TRACKED_OBJECTS 160
string g_objNames[];

//====================================================================
// LIFECYCLE
//====================================================================
int OnInit()
{
   for(int i=0;i<PAIR_COUNT;i++)
      InitPairState(g_pairs[i], g_tags[i], 0);
   ArrayResize(g_objNames,0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   for(int i=ArraySize(g_objNames)-1;i>=0;i--)
      ObjectDelete(0, g_objNames[i]);
   ArrayResize(g_objNames,0);
   ObjectsDeleteAll(0, OBJ_PREFIX);
   Comment("");
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                 const double &open[], const double &high[], const double &low[], const double &close[],
                 const long &tick_volume[], const long &volume[], const int &spread[])
{
   ProcessAll();
   return(rates_total);
}

//====================================================================
// OBJECT TRACKING (cap chart clutter)
//====================================================================
void TrackObject(string name)
{
   int n=ArraySize(g_objNames);
   ArrayResize(g_objNames, n+1);
   g_objNames[n]=name;
   if(ArraySize(g_objNames) > MAX_TRACKED_OBJECTS)
   {
      ObjectDelete(0, g_objNames[0]);
      for(int i=0;i<ArraySize(g_objNames)-1;i++) g_objNames[i]=g_objNames[i+1];
      ArrayResize(g_objNames, ArraySize(g_objNames)-1);
   }
}

//====================================================================
// MAIN PROCESSING
//====================================================================
void ProcessAll()
{
   datetime dayStamp = TimeCurrent() - (TimeCurrent() % 86400);
   if(dayStamp != g_lastDayStamp) { g_lastDayStamp=dayStamp; g_tradesToday=0; }

   int startH,startM,endH,endM;
   ResolveSessionPreset(InpSessionPreset, InpCustomSessionStartHour, InpCustomSessionStartMin,
                        InpCustomSessionEndHour, InpCustomSessionEndMin, startH,startM,endH,endM);
   bool sessionOk = InSession(InpEnableSession, startH,startM,endH,endM, InpBrokerGMTOffset);
   bool canTradeMore = (InpMaxTradesPerDay<=0) || (g_tradesToday < InpMaxTradesPerDay);

   bool je, sd, zf, hb, bt;
   string symbol = Symbol();

   // ---- Strategy 1 : two pairs ----
   UpdateSweepPair(g_pairs[0], symbol, InpEnableS1 && InpS1_4H_On, InpS1_4H_TF, InpEnableS1 && InpS1_5M_On, InpS1_5M_TF,
      InpS1_RequireFullClose, InpS1_UseOB, InpS1_UseFVG, InpS1_MaxWaitBars, InpS1_OneSignalPerSweep,
      InpRRMultiple, canTradeMore, sessionOk, InpSLTPMethod, InpSLPercent, InpTPPercent,
      InpEnableBE, InpBETriggerR, true, je,sd,zf,hb,bt);
   HandlePairResult(0, je,sd,zf,hb,bt, InpS1_5M_TF);

   UpdateSweepPair(g_pairs[1], symbol, InpEnableS1 && InpS1_1H_On, InpS1_1H_TF, InpEnableS1 && InpS1_1M_On, InpS1_1M_TF,
      InpS1_RequireFullClose, InpS1_UseOB, InpS1_UseFVG, InpS1_MaxWaitBars, InpS1_OneSignalPerSweep,
      InpRRMultiple, canTradeMore, sessionOk, InpSLTPMethod, InpSLPercent, InpTPPercent,
      InpEnableBE, InpBETriggerR, true, je,sd,zf,hb,bt);
   HandlePairResult(1, je,sd,zf,hb,bt, InpS1_1M_TF);

   // ---- Strategy 2 : two pairs ----
   UpdateContPair(g_pairs[2], symbol, InpEnableS2 && InpS2_1H_On, InpS2_1H_TF, InpEnableS2 && InpS2_1M_On, InpS2_1M_TF,
      InpS2_TrendMethod, InpS2_EmaLen, InpS2_SwingN, InpS2_ManualBias, InpS2_RequireFullClose,
      InpS2_MaxWaitBars, InpS2_OneSignalPerCont, InpRRMultiple, canTradeMore, sessionOk,
      InpSLTPMethod, InpSLPercent, InpTPPercent, InpEnableBE, InpBETriggerR, true, je,sd,zf,hb,bt);
   HandlePairResult(2, je,sd,zf,hb,bt, InpS2_1M_TF);

   UpdateContPair(g_pairs[3], symbol, InpEnableS2 && InpS2_4H_On, InpS2_4H_TF, InpEnableS2 && InpS2_5M_On, InpS2_5M_TF,
      InpS2_TrendMethod, InpS2_EmaLen, InpS2_SwingN, InpS2_ManualBias, InpS2_RequireFullClose,
      InpS2_MaxWaitBars, InpS2_OneSignalPerCont, InpRRMultiple, canTradeMore, sessionOk,
      InpSLTPMethod, InpSLPercent, InpTPPercent, InpEnableBE, InpBETriggerR, true, je,sd,zf,hb,bt);
   HandlePairResult(3, je,sd,zf,hb,bt, InpS2_5M_TF);

   // ---- Strategy 3 : single pair ----
   UpdateDivPair(g_pairs[4], symbol, InpEnableS3, InpS3_DivTF, InpS3_TFMode, InpS3_EntryTF,
      InpS3_RsiLen, InpS3_PivotLeft, InpS3_PivotRight, InpS3_MaxDivBars, InpS3_EntryMode,
      InpS3_UseOB, InpS3_UseFVG, InpS3_MaxWaitBars, InpS3_OneSignalPerDiv, InpRRMultiple,
      canTradeMore, sessionOk, InpSLTPMethod, InpSLPercent, InpTPPercent, InpEnableBE, InpBETriggerR,
      true, je,sd,zf,hb,bt);
   HandlePairResult(4, je,sd,zf,hb,bt, (InpS3_TFMode==TFMODE_PAIR ? InpS3_EntryTF : InpS3_DivTF));

   // ---- Strategy 4 : single pair ----
   UpdateBBPair(g_pairs[5], symbol, InpEnableS4, InpS4_BBTF, InpS4_TFMode, InpS4_EntryTF,
      InpS4_BBLen, InpS4_BBMult, InpS4_BBMode, InpS4_EntryMode, InpS4_UseOB, InpS4_UseFVG,
      InpS4_MaxWaitBars, InpS4_OneSignalPerBB, InpRRMultiple, canTradeMore, sessionOk,
      InpSLTPMethod, InpSLPercent, InpTPPercent, InpEnableBE, InpBETriggerR, true, je,sd,zf,hb,bt);
   HandlePairResult(5, je,sd,zf,hb,bt, (InpS4_TFMode==TFMODE_PAIR ? InpS4_EntryTF : InpS4_BBTF));

   if(InpShowInfoPanel) DrawPanel();
}

void HandlePairResult(int idx, bool justEntered, bool detected, bool zoneFound, bool htfSeen, bool beTriggered, ENUM_TIMEFRAMES entryTF)
{
   if(htfSeen) g_htfBarsProcessed++;
   if(detected) g_signalsDetected++;
   if(zoneFound)
   {
      g_zonesFound++;
      DrawZoneBox(idx, entryTF);
   }
   if(justEntered)
   {
      g_entriesTriggered++;
      g_tradesToday++;
      DrawEntrySignal(idx);
      string dirTxt = (g_pairs[idx].tradeDir==1) ? "BUY" : "SELL";
      g_lastSignalText = StringFormat("%s %s @ %s (SL %s / TP %s) %s",
         g_tags[idx], dirTxt, DoubleToString(g_pairs[idx].entryPx,Digits),
         DoubleToString(g_pairs[idx].slPx,Digits), DoubleToString(g_pairs[idx].tpPx,Digits),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      FireAlert(g_lastSignalText);
   }
   if(beTriggered)
      FireAlert(StringFormat("%s break-even triggered, stop moved to %s", g_tags[idx], DoubleToString(g_pairs[idx].slPx,Digits)));
}

void FireAlert(string msg)
{
   if(InpEnablePopupAlert) Alert(msg);
   if(InpEnableAlerts) Print(msg);
   if(InpEnablePushNotify) SendNotification(msg);
}

//====================================================================
// DRAWING
//====================================================================
void DrawZoneBox(int idx, ENUM_TIMEFRAMES entryTF)
{
   PairState st = g_pairs[idx];
   string name = OBJ_PREFIX + "Zone_" + IntegerToString(idx) + "_" + IntegerToString((int)TimeCurrent());
   int periodSecs = PeriodSeconds(entryTF);
   datetime t1 = TimeCurrent() - 2*periodSecs;
   datetime t2 = TimeCurrent() + 20*periodSecs;
   color c = (st.dirState==1) ? InpBullColor : InpBearColor;

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, st.zoneTop, t2, st.zoneBot);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   TrackObject(name);

   string lblName = name + "_lbl";
   ObjectCreate(0, lblName, OBJ_TEXT, 0, t1, st.zoneTop);
   ObjectSetString(0, lblName, OBJPROP_TEXT, "Zone [" + g_tags[idx] + "]");
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, c);
   TrackObject(lblName);
}

void DrawEntrySignal(int idx)
{
   PairState st = g_pairs[idx];
   bool isBuy = (st.tradeDir==1);
   string name = OBJ_PREFIX + "Sig_" + IntegerToString(idx) + "_" + IntegerToString((int)TimeCurrent());
   double price = isBuy ? Low[0] : High[0];

   ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, isBuy ? clrLime : clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   TrackObject(name);

   string lblName = name + "_lbl";
   ObjectCreate(0, lblName, OBJ_TEXT, 0, TimeCurrent(), price);
   ObjectSetString(0, lblName, OBJPROP_TEXT, (isBuy?"BUY ":"SELL ") + g_tags[idx]);
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, isBuy ? clrLime : clrRed);
   TrackObject(lblName);

   if(InpShowSLTPLabels)
   {
      string slName = name + "_sl";
      ObjectCreate(0, slName, OBJ_HLINE, 0, 0, st.slPx);
      ObjectSetInteger(0, slName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, slName, OBJPROP_TEXT, "SL " + g_tags[idx] + " " + DoubleToString(st.slPx,Digits));
      TrackObject(slName);

      string tpName = name + "_tp";
      ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, st.tpPx);
      ObjectSetInteger(0, tpName, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, tpName, OBJPROP_TEXT, "TP " + g_tags[idx] + " " + DoubleToString(st.tpPx,Digits));
      TrackObject(tpName);
   }
}

void DrawPanel()
{
   int x=10, y=20, dy=16;
   string enabledStr = (InpEnableS1?"S1 ":"") + (InpEnableS2?"S2 ":"") + (InpEnableS3?"S3 ":"") + (InpEnableS4?"S4 ":"");
   if(StringLen(enabledStr)==0) enabledStr="(none)";

   PanelLabel("TFMS_p_title", "TrendFocus Multi-Strategy (signals only)", x, y); y+=dy;
   PanelLabel("TFMS_p_enabled", "Enabled: " + enabledStr, x, y); y+=dy;
   PanelLabel("TFMS_p_htf", "HTF Bars Processed: " + IntegerToString(g_htfBarsProcessed), x, y); y+=dy;
   PanelLabel("TFMS_p_sig", "Signals Detected: " + IntegerToString(g_signalsDetected), x, y); y+=dy;
   PanelLabel("TFMS_p_zone", "Zones Found: " + IntegerToString(g_zonesFound), x, y); y+=dy;
   PanelLabel("TFMS_p_entries", "Entries Triggered: " + IntegerToString(g_entriesTriggered), x, y); y+=dy;
   string capTxt = (InpMaxTradesPerDay>0) ? (IntegerToString(g_tradesToday)+" / "+IntegerToString(InpMaxTradesPerDay)) : IntegerToString(g_tradesToday);
   PanelLabel("TFMS_p_today", "Signals Today: " + capTxt, x, y); y+=dy;
   PanelLabel("TFMS_p_last", "Last Signal: " + g_lastSignalText, x, y); y+=dy;
   PanelLabel("TFMS_p_note", "Indicator does not trade -- use the companion EA to execute.", x, y);
}

void PanelLabel(string name, string text, int x, int y)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}
//+------------------------------------------------------------------+
