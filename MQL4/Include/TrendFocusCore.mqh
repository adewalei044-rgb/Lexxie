//+------------------------------------------------------------------+
//| TrendFocusCore.mqh                                                |
//| Shared multi-strategy signal engine used by both                  |
//| TrendFocus_MultiStrategy.mq4 (indicator) and                      |
//| TrendFocus_MultiStrategy_EA.mq4 (expert advisor).                 |
//|                                                                    |
//| Ports the four-strategy Pine Script (Sweep Reversal, Trend         |
//| Continuation, RSI Divergence, Bollinger Bands) to MQL4. Unlike    |
//| Pine's request.security(), MQL4's iOpen/iHigh/iLow/iClose(...,1)  |
//| give direct, reliable access to the last CLOSED bar on any        |
//| timeframe, so "new bar" detection here is simpler than Pine's:    |
//| we only need to notice that iTime(symbol,tf,0) changed, then read |
//| shift=1 directly as the just-closed candle.                       |
//|                                                                    |
//| This file contains ONLY signal-detection logic -- no chart         |
//| objects, no OrderSend calls. The indicator draws based on the      |
//| PairState fields after calling an Update*Pair function; the EA    |
//| trades based on the same fields.                                   |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// ENUMS (shared option lists for indicator + EA inputs)
//====================================================================
enum ENUM_TREND_METHOD  { TREND_AUTO_EMA, TREND_AUTO_STRUCTURE, TREND_MANUAL };
enum ENUM_MANUAL_BIAS   { BIAS_BULLISH, BIAS_BEARISH, BIAS_BOTH };
enum ENUM_TF_MODE       { TFMODE_SINGLE, TFMODE_PAIR };
enum ENUM_DIV_ENTRY_MODE{ DIVMODE_ALONE, DIVMODE_ZONE };
enum ENUM_BB_SIGNAL_MODE{ BB_MEAN_REVERSION, BB_BREAKOUT };
enum ENUM_BB_ENTRY_MODE { BBMODE_ALONE, BBMODE_ZONE };
enum ENUM_SLTP_METHOD   { SLTP_STRUCTURAL, SLTP_FIXED_PERCENT };
enum ENUM_SESSION_PRESET{ SESSION_LONDON, SESSION_NEWYORK, SESSION_ASIAN, SESSION_OVERLAP, SESSION_CUSTOM };
enum ENUM_POS_SIZE_MODE { SIZE_FIXED_LOTS, SIZE_FIXED_MONEY, SIZE_RISK_PERCENT };

//====================================================================
// PairState -- one instance per pair/strategy combo (up to 6:
// S1 4H/5M, S1 1H/1M, S2 1H/1M, S2 4H/5M, S3 Div, S4 BB)
//====================================================================
struct PairState
{
   // new-bar detection
   bool     htfValid;    datetime htfTime;
   bool     entryValid;  datetime entryTime;

   // reference candle shift register (sweep: c1/c2, continuation: p_/x_)
   bool     ref1Valid, ref2Valid;
   double   ref1O,ref1H,ref1L,ref1C;
   double   ref2O,ref2H,ref2L,ref2C;

   bool     armed, waitingEntry;
   int      dirState;      // 1 bull, -1 bear, 0 none
   int      barsWaited;

   bool     anchorValid;   double anchorPx;   // divergence pivot / BB anchor

   // entry-timeframe rolling candle history
   bool     e1Valid,e2Valid,e3Valid;
   double   e1O,e1H,e1L,e1C;
   double   e2O,e2H,e2L,e2C;
   double   e3O,e3H,e3L,e3C;

   bool     zoneValid;     double zoneTop, zoneBot;

   bool     inTrade;       int tradeDir;
   double   entryPx, slPx, tpPx;
   bool     beDone;
   int      ticket;        // EA only; -1 when none

   // RSI divergence pivot memory
   bool     havePL, havePH;
   double   prevPLPrice, prevPLRsi;  datetime prevPLTime;
   double   prevPHPrice, prevPHRsi;  datetime prevPHTime;

   string   tag;
   int      magic;
};

void InitPairState(PairState &st, string tag, int magic)
{
   st.htfValid=false;   st.htfTime=0;
   st.entryValid=false; st.entryTime=0;
   st.ref1Valid=false;  st.ref2Valid=false;
   st.armed=false; st.waitingEntry=false; st.dirState=0; st.barsWaited=0;
   st.anchorValid=false; st.anchorPx=0;
   st.e1Valid=false; st.e2Valid=false; st.e3Valid=false;
   st.zoneValid=false; st.zoneTop=0; st.zoneBot=0;
   st.inTrade=false; st.tradeDir=0;
   st.entryPx=0; st.slPx=0; st.tpPx=0; st.beDone=false; st.ticket=-1;
   st.havePL=false; st.havePH=false;
   st.prevPLPrice=0; st.prevPLRsi=0; st.prevPLTime=0;
   st.prevPHPrice=0; st.prevPHRsi=0; st.prevPHTime=0;
   st.tag=tag; st.magic=magic;
}

void ResetPairAfterClose(PairState &st, bool oneSignalFlag)
{
   st.inTrade=false; st.armed=false; st.waitingEntry=false; st.tradeDir=0;
   st.ticket=-1;
   if(oneSignalFlag) st.zoneValid=false;
}

//====================================================================
// GENERIC HELPERS
//====================================================================
int GetTrendDir(string symbol, ENUM_TIMEFRAMES tf, ENUM_TREND_METHOD method,
                int emaLen, int swingN, ENUM_MANUAL_BIAS manualBias)
{
   double closeVal = iClose(symbol, tf, 0);
   if(method==TREND_MANUAL)
   {
      if(manualBias==BIAS_BULLISH) return 1;
      if(manualBias==BIAS_BEARISH) return -1;
      return 2; // Both -- no directional filter
   }
   if(method==TREND_AUTO_EMA)
   {
      double emaVal = iMA(symbol, tf, emaLen, 0, MODE_EMA, PRICE_CLOSE, 0);
      if(closeVal>emaVal) return 1;
      if(closeVal<emaVal) return -1;
      return 0;
   }
   // Auto (Structure): simplified proxy, current close vs close N bars back
   double pastClose = iClose(symbol, tf, swingN);
   if(closeVal>pastClose) return 1;
   if(closeVal<pastClose) return -1;
   return 0;
}

// Regular RSI divergence pivot: candidate pivot bar sits `right` closed bars
// behind the current bar. center = right+1 guarantees both the pivot bar
// and all `right` bars compared against it are fully closed (shift ftime >=1).
bool CheckPivotLow(string symbol, ENUM_TIMEFRAMES tf, int rsiLen, int left, int right, double &pivotRsiOut)
{
   int center = right+1;
   double centerVal = iRSI(symbol, tf, rsiLen, PRICE_CLOSE, center);
   for(int i=1;i<=right;i++)
      if(iRSI(symbol, tf, rsiLen, PRICE_CLOSE, center-i) < centerVal) return false;
   for(int i=1;i<=left;i++)
      if(iRSI(symbol, tf, rsiLen, PRICE_CLOSE, center+i) < centerVal) return false;
   pivotRsiOut = centerVal;
   return true;
}

bool CheckPivotHigh(string symbol, ENUM_TIMEFRAMES tf, int rsiLen, int left, int right, double &pivotRsiOut)
{
   int center = right+1;
   double centerVal = iRSI(symbol, tf, rsiLen, PRICE_CLOSE, center);
   for(int i=1;i<=right;i++)
      if(iRSI(symbol, tf, rsiLen, PRICE_CLOSE, center-i) > centerVal) return false;
   for(int i=1;i<=left;i++)
      if(iRSI(symbol, tf, rsiLen, PRICE_CLOSE, center+i) > centerVal) return false;
   pivotRsiOut = centerVal;
   return true;
}

void ResolveSessionPreset(ENUM_SESSION_PRESET preset,
                           int customStartH,int customStartM,int customEndH,int customEndM,
                           int &startH,int &startM,int &endH,int &endM)
{
   switch(preset)
   {
      case SESSION_LONDON:   startH=7;  startM=0; endH=16; endM=0; break;
      case SESSION_NEWYORK:  startH=13; startM=0; endH=22; endM=0; break;
      case SESSION_ASIAN:    startH=0;  startM=0; endH=9;  endM=0; break;
      case SESSION_OVERLAP:  startH=13; startM=0; endH=16; endM=0; break;
      default:               startH=customStartH; startM=customStartM; endH=customEndH; endM=customEndM; break;
   }
}

// brokerGmtOffset = hours the broker's server clock is ahead of UTC. Session
// window is defined in UTC (matching the Pine defaults), so broker time is
// shifted back by that offset before comparing against the window.
bool InSession(bool enable, int startH,int startM,int endH,int endM, int brokerGmtOffset)
{
   if(!enable) return true;
   datetime now = TimeCurrent();
   int totalBrokerMin = TimeHour(now)*60 + TimeMinute(now);
   int targetMin = totalBrokerMin - brokerGmtOffset*60;
   targetMin = ((targetMin % 1440) + 1440) % 1440;
   int startTotal = startH*60+startM;
   int endTotal   = endH*60+endM;
   if(startTotal<=endTotal) return (targetMin>=startTotal && targetMin<endTotal);
   return (targetMin>=startTotal || targetMin<endTotal); // window crosses midnight
}

// Risk-based (or fixed) lot sizing. SIZE_RISK_PERCENT is the recommended
// mode: it sizes off the actual SL distance and account equity, so a wider
// stop always risks the same dollar amount as a tighter one -- true risk
// management, unlike Pine's fixed-cash default_qty_type which sizes
// identically regardless of stop distance.
double CalcLots(string symbol, ENUM_POS_SIZE_MODE mode, double fixedLots, double fixedMoney,
                 double riskPercent, double entryPx, double slPx)
{
   double lots = 0;
   if(mode==SIZE_FIXED_LOTS)
   {
      lots = fixedLots;
   }
   else if(mode==SIZE_FIXED_MONEY)
   {
      // Approximation: assumes account currency == symbol's quote currency.
      // For an accurate cross-currency notional, use SIZE_RISK_PERCENT instead.
      double lotSize = MarketInfo(symbol, MODE_LOTSIZE);
      if(lotSize<=0) lotSize=100000;
      lots = (entryPx>0) ? fixedMoney/(lotSize*entryPx) : 0;
   }
   else
   {
      double riskMoney = AccountEquity()*riskPercent/100.0;
      double slDist = MathAbs(entryPx-slPx);
      double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
      double tickSize  = MarketInfo(symbol, MODE_TICKSIZE);
      if(slDist<=0 || tickSize<=0 || tickValue<=0) return 0;
      double valuePerUnit = tickValue/tickSize;
      lots = riskMoney/(slDist*valuePerUnit);
   }
   double minLot  = MarketInfo(symbol, MODE_MINLOT);
   double maxLot  = MarketInfo(symbol, MODE_MAXLOT);
   double lotStep = MarketInfo(symbol, MODE_LOTSTEP);
   if(lotStep>0) lots = MathFloor(lots/lotStep)*lotStep;
   if(lots<minLot) lots=minLot;
   if(maxLot>0 && lots>maxLot) lots=maxLot;
   return NormalizeDouble(lots,2);
}

// Shared OB/FVG pullback-zone detection, identical rules used by all four
// strategies' "zone pullback" entry paths.
bool DetectZone(PairState &st, bool useOB, bool useFVG, double &zTop, double &zBot)
{
   bool gotZone=false;
   if(st.dirState==1)
   {
      if(useFVG && st.e1Valid && st.e3L > st.e1H)
      { zTop=st.e3L; zBot=st.e1H; gotZone=true; }
      else if(useOB && st.e2Valid && st.e2C<st.e2O && st.e3C>st.e3O && st.e3C>st.e2H)
      { zTop=st.e2H; zBot=st.e2L; gotZone=true; }
   }
   else if(st.dirState==-1)
   {
      if(useFVG && st.e1Valid && st.e3H < st.e1L)
      { zTop=st.e1L; zBot=st.e3H; gotZone=true; }
      else if(useOB && st.e2Valid && st.e2C>st.e2O && st.e3C<st.e3O && st.e3C<st.e2L)
      { zTop=st.e2H; zBot=st.e2L; gotZone=true; }
   }
   return gotZone;
}

void ShiftEntryHistory(PairState &st, string symbol, ENUM_TIMEFRAMES entryTF)
{
   st.e1O=st.e2O; st.e1H=st.e2H; st.e1L=st.e2L; st.e1C=st.e2C; st.e1Valid=st.e2Valid;
   st.e2O=st.e3O; st.e2H=st.e3H; st.e2L=st.e3L; st.e2C=st.e3C; st.e2Valid=st.e3Valid;
   st.e3O=iOpen(symbol,entryTF,1); st.e3H=iHigh(symbol,entryTF,1);
   st.e3L=iLow(symbol,entryTF,1);  st.e3C=iClose(symbol,entryTF,1);
   st.e3Valid=true;
}

// selfManageExit==true: used by the indicator (no real orders) to simulate
// SL/TP/BE against the entry timeframe's own live bar, purely so its panel
// and drawings can show a hypothetical outcome. The EA sets this false and
// manages real order exits itself via ResetPairAfterClose().
void ManageSimulatedExit(PairState &st, string symbol, ENUM_TIMEFRAMES entryTF,
                          bool enableBE, double beTriggerR, bool oneSignalFlag,
                          bool &beTriggered)
{
   if(!st.inTrade) return;
   double liveH = iHigh(symbol, entryTF, 0);
   double liveL = iLow(symbol, entryTF, 0);
   if(st.tradeDir==1)
   {
      if(enableBE && !st.beDone && liveH >= st.entryPx + (st.entryPx-st.slPx)*beTriggerR)
      { st.slPx=st.entryPx; st.beDone=true; beTriggered=true; }
      if(liveH >= st.tpPx || liveL <= st.slPx) st.inTrade=false;
   }
   else
   {
      if(enableBE && !st.beDone && liveL <= st.entryPx - (st.slPx-st.entryPx)*beTriggerR)
      { st.slPx=st.entryPx; st.beDone=true; beTriggered=true; }
      if(liveL <= st.tpPx || liveH >= st.slPx) st.inTrade=false;
   }
   if(!st.inTrade) ResetPairAfterClose(st, oneSignalFlag);
}

//====================================================================
// STRATEGY 1 ENGINE -- SWEEP REVERSAL
//====================================================================
void UpdateSweepPair(PairState &st, string symbol,
   bool sweepOn, ENUM_TIMEFRAMES sweepTF, bool entryOn, ENUM_TIMEFRAMES entryTF,
   bool requireFullClose, bool useOB, bool useFVG, int maxWaitBars, bool oneSignalPerSweep,
   double rr, bool canTradeMore, bool sessionOk,
   ENUM_SLTP_METHOD slTpMethod, double slPct, double tpPct,
   bool enableBE, double beTriggerR, bool selfManageExit,
   bool &justEntered, bool &sweepJustDetected, bool &zoneJustFound, bool &htfBarSeen, bool &beTriggered)
{
   justEntered=false; sweepJustDetected=false; zoneJustFound=false; htfBarSeen=false; beTriggered=false;
   if(!(sweepOn && entryOn)) return;

   datetime t0S = iTime(symbol, sweepTF, 0);
   datetime t0E = iTime(symbol, entryTF, 0);
   bool newSweepBar = st.htfValid && (t0S != st.htfTime);
   bool newEntryBar = st.entryValid && (t0E != st.entryTime);
   st.htfTime=t0S; st.htfValid=true;
   st.entryTime=t0E; st.entryValid=true;

   if(newSweepBar)
   {
      htfBarSeen=true;
      if(!st.armed)
      {
         st.ref1O=st.ref2O; st.ref1H=st.ref2H; st.ref1L=st.ref2L; st.ref1C=st.ref2C; st.ref1Valid=st.ref2Valid;
         st.ref2O=iOpen(symbol,sweepTF,1); st.ref2H=iHigh(symbol,sweepTF,1);
         st.ref2L=iLow(symbol,sweepTF,1);  st.ref2C=iClose(symbol,sweepTF,1);
         st.ref2Valid=true;

         if(st.ref1Valid)
         {
            bool c1Bull = st.ref1C > st.ref1O;
            bool c2Bull = st.ref2C > st.ref2O;
            bool oppColors = (c1Bull != c2Bull);
            bool bearSweep = (st.ref2L < st.ref1L) && (!requireFullClose || st.ref2C < st.ref1L);
            bool bullSweep = (st.ref2H > st.ref1H) && (!requireFullClose || st.ref2C > st.ref1H);

            if(oppColors && bearSweep && !bullSweep)
            { st.dirState=1; st.armed=true; st.waitingEntry=true; st.barsWaited=0; sweepJustDetected=true; }
            else if(oppColors && bullSweep && !bearSweep)
            { st.dirState=-1; st.armed=true; st.waitingEntry=true; st.barsWaited=0; sweepJustDetected=true; }
         }
      }
      else if(st.waitingEntry)
      {
         double closedSC = iClose(symbol,sweepTF,1);
         if(st.dirState==1  && closedSC < st.ref2L) { st.armed=false; st.waitingEntry=false; }
         if(st.dirState==-1 && closedSC > st.ref2H) { st.armed=false; st.waitingEntry=false; }
      }
   }

   if(st.waitingEntry && newEntryBar)
   {
      st.barsWaited++;
      if(st.barsWaited > maxWaitBars) { st.armed=false; st.waitingEntry=false; }
   }

   if(newEntryBar) ShiftEntryHistory(st, symbol, entryTF);

   bool zoneJustSet=false;
   if(newEntryBar && st.armed && st.waitingEntry && !st.inTrade)
   {
      double zTop=0, zBot=0;
      if(DetectZone(st, useOB, useFVG, zTop, zBot))
      { st.zoneTop=zTop; st.zoneBot=zBot; st.zoneValid=true; zoneJustSet=true; zoneJustFound=true; }
   }

   if(newEntryBar && !zoneJustSet && st.armed && st.waitingEntry && !st.inTrade && st.zoneValid && canTradeMore && sessionOk)
   {
      if(st.dirState==1 && st.e3L<=st.zoneTop && st.e3C>st.zoneBot && st.e3C>st.e3O)
      {
         st.inTrade=true; st.tradeDir=1; st.entryPx=st.e3C;
         if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1-slPct/100.0); st.tpPx=st.entryPx*(1+tpPct/100.0); }
         else { st.slPx=MathMin(st.zoneBot, st.ref2L); double riskPts=st.entryPx-st.slPx; st.tpPx=st.entryPx+riskPts*rr; }
         st.beDone=false; st.waitingEntry=false; justEntered=true;
      }
      else if(st.dirState==-1 && st.e3H>=st.zoneBot && st.e3C<st.zoneTop && st.e3C<st.e3O)
      {
         st.inTrade=true; st.tradeDir=-1; st.entryPx=st.e3C;
         if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1+slPct/100.0); st.tpPx=st.entryPx*(1-tpPct/100.0); }
         else { st.slPx=MathMax(st.zoneTop, st.ref2H); double riskPts=st.slPx-st.entryPx; st.tpPx=st.entryPx-riskPts*rr; }
         st.beDone=false; st.waitingEntry=false; justEntered=true;
      }
   }

   if(selfManageExit)
      ManageSimulatedExit(st, symbol, entryTF, enableBE, beTriggerR, oneSignalPerSweep, beTriggered);
}

//====================================================================
// STRATEGY 2 ENGINE -- TREND CONTINUATION + FVG ENTRY
//====================================================================
void UpdateContPair(PairState &st, string symbol,
   bool trendOn, ENUM_TIMEFRAMES trendTF, bool entryOn, ENUM_TIMEFRAMES entryTF,
   ENUM_TREND_METHOD trendMethod, int emaLen, int swingN, ENUM_MANUAL_BIAS manualBias,
   bool requireFullClose, int maxWaitBars, bool oneSignalPerCont,
   double rr, bool canTradeMore, bool sessionOk,
   ENUM_SLTP_METHOD slTpMethod, double slPct, double tpPct,
   bool enableBE, double beTriggerR, bool selfManageExit,
   bool &justEntered, bool &contJustDetected, bool &zoneJustFound, bool &htfBarSeen, bool &beTriggered)
{
   justEntered=false; contJustDetected=false; zoneJustFound=false; htfBarSeen=false; beTriggered=false;
   if(!(trendOn && entryOn)) return;

   datetime t0T = iTime(symbol, trendTF, 0);
   datetime t0E = iTime(symbol, entryTF, 0);
   bool newTrendBar = st.htfValid && (t0T != st.htfTime);
   bool newEntryBar = st.entryValid && (t0E != st.entryTime);
   st.htfTime=t0T; st.htfValid=true;
   st.entryTime=t0E; st.entryValid=true;

   int trendDirNow = GetTrendDir(symbol, trendTF, trendMethod, emaLen, swingN, manualBias);

   if(newTrendBar)
   {
      htfBarSeen=true;
      if(!st.armed)
      {
         st.ref1O=st.ref2O; st.ref1H=st.ref2H; st.ref1L=st.ref2L; st.ref1C=st.ref2C; st.ref1Valid=st.ref2Valid;
         st.ref2O=iOpen(symbol,trendTF,1); st.ref2H=iHigh(symbol,trendTF,1);
         st.ref2L=iLow(symbol,trendTF,1);  st.ref2C=iClose(symbol,trendTF,1);
         st.ref2Valid=true;

         if(st.ref1Valid)
         {
            bool xBull = st.ref2C > st.ref2O;
            bool contBull = (trendDirNow==1 || trendDirNow==2) && xBull  && (requireFullClose ? st.ref2C>st.ref1H : st.ref2H>st.ref1H);
            bool contBear = (trendDirNow==-1|| trendDirNow==2) && !xBull && (requireFullClose ? st.ref2C<st.ref1L : st.ref2L<st.ref1L);

            if(contBull)      { st.dirState=1;  st.armed=true; st.waitingEntry=true; st.barsWaited=0; contJustDetected=true; }
            else if(contBear) { st.dirState=-1; st.armed=true; st.waitingEntry=true; st.barsWaited=0; contJustDetected=true; }
         }
      }
      else if(st.waitingEntry)
      {
         double closedTC = iClose(symbol,trendTF,1);
         if(st.dirState==1  && closedTC < st.ref2O) { st.armed=false; st.waitingEntry=false; }
         if(st.dirState==-1 && closedTC > st.ref2O) { st.armed=false; st.waitingEntry=false; }
      }
   }

   if(st.waitingEntry && newEntryBar)
   {
      st.barsWaited++;
      if(st.barsWaited > maxWaitBars) { st.armed=false; st.waitingEntry=false; }
   }

   if(newEntryBar) ShiftEntryHistory(st, symbol, entryTF);

   // Strategy 2 only ever uses FVG zones (no OB), matching the Pine source.
   bool zoneJustSet=false;
   if(newEntryBar && st.armed && st.waitingEntry && !st.inTrade)
   {
      double zTop=0, zBot=0; bool gotZone=false;
      if(st.dirState==1  && st.e1Valid && st.e3L > st.e1H) { zTop=st.e3L; zBot=st.e1H; gotZone=true; }
      else if(st.dirState==-1 && st.e1Valid && st.e3H < st.e1L) { zTop=st.e1L; zBot=st.e3H; gotZone=true; }
      if(gotZone) { st.zoneTop=zTop; st.zoneBot=zBot; st.zoneValid=true; zoneJustSet=true; zoneJustFound=true; }
   }

   if(newEntryBar && !zoneJustSet && st.armed && st.waitingEntry && !st.inTrade && st.zoneValid && canTradeMore && sessionOk)
   {
      if(st.dirState==1 && st.e3L<=st.zoneTop && st.e3C>st.zoneBot && st.e3C>st.e3O)
      {
         st.inTrade=true; st.tradeDir=1; st.entryPx=st.e3C;
         if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1-slPct/100.0); st.tpPx=st.entryPx*(1+tpPct/100.0); }
         else { st.slPx=MathMin(st.zoneBot, st.ref2O); double riskPts=st.entryPx-st.slPx; st.tpPx=st.entryPx+riskPts*rr; }
         st.beDone=false; st.waitingEntry=false; justEntered=true;
      }
      else if(st.dirState==-1 && st.e3H>=st.zoneBot && st.e3C<st.zoneTop && st.e3C<st.e3O)
      {
         st.inTrade=true; st.tradeDir=-1; st.entryPx=st.e3C;
         if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1+slPct/100.0); st.tpPx=st.entryPx*(1-tpPct/100.0); }
         else { st.slPx=MathMax(st.zoneTop, st.ref2O); double riskPts=st.slPx-st.entryPx; st.tpPx=st.entryPx-riskPts*rr; }
         st.beDone=false; st.waitingEntry=false; justEntered=true;
      }
   }

   if(selfManageExit)
      ManageSimulatedExit(st, symbol, entryTF, enableBE, beTriggerR, oneSignalPerCont, beTriggered);
}

//====================================================================
// STRATEGY 3 ENGINE -- REGULAR RSI DIVERGENCE
//====================================================================
void UpdateDivPair(PairState &st, string symbol,
   bool pairOn, ENUM_TIMEFRAMES divTF, ENUM_TF_MODE tfMode, ENUM_TIMEFRAMES entryTFin,
   int rsiLen, int pivotLeft, int pivotRight, int maxDivBars,
   ENUM_DIV_ENTRY_MODE entryMode, bool useOB, bool useFVG, int maxWaitBars, bool oneSignalPerDiv,
   double rr, bool canTradeMore, bool sessionOk,
   ENUM_SLTP_METHOD slTpMethod, double slPct, double tpPct,
   bool enableBE, double beTriggerR, bool selfManageExit,
   bool &justEntered, bool &divJustDetected, bool &zoneJustFound, bool &htfBarSeen, bool &beTriggered)
{
   justEntered=false; divJustDetected=false; zoneJustFound=false; htfBarSeen=false; beTriggered=false;
   if(!pairOn) return;

   ENUM_TIMEFRAMES entryTF = (tfMode==TFMODE_PAIR) ? entryTFin : divTF;
   bool useZonePullback = (entryMode==DIVMODE_ZONE);

   datetime t0D = iTime(symbol, divTF, 0);
   datetime t0E = iTime(symbol, entryTF, 0);
   bool newDivBar   = st.htfValid && (t0D != st.htfTime);
   bool newEntryBar = st.entryValid && (t0E != st.entryTime);
   st.htfTime=t0D; st.htfValid=true;
   st.entryTime=t0E; st.entryValid=true;

   if(newDivBar)
   {
      htfBarSeen=true;
      double plRsi=0, phRsi=0;
      bool isPL = CheckPivotLow(symbol, divTF, rsiLen, pivotLeft, pivotRight, plRsi);
      bool isPH = CheckPivotHigh(symbol, divTF, rsiLen, pivotLeft, pivotRight, phRsi);

      bool bullDiv=false, bearDiv=false; double pivotBullPx=0, pivotBearPx=0;

      if(isPL)
      {
         double curPrice = iLow(symbol, divTF, pivotRight+1);
         datetime curTime = iTime(symbol, divTF, pivotRight+1);
         if(st.havePL)
         {
            int barsBetween = (int)MathRound((double)(curTime-st.prevPLTime)/(double)PeriodSeconds(divTF));
            if(barsBetween<=maxDivBars && curPrice<st.prevPLPrice && plRsi>st.prevPLRsi)
            { bullDiv=true; pivotBullPx=curPrice; }
         }
         st.prevPLPrice=curPrice; st.prevPLRsi=plRsi; st.prevPLTime=curTime; st.havePL=true;
      }
      if(isPH)
      {
         double curPriceH = iHigh(symbol, divTF, pivotRight+1);
         datetime curTimeH = iTime(symbol, divTF, pivotRight+1);
         if(st.havePH)
         {
            int barsBetweenH = (int)MathRound((double)(curTimeH-st.prevPHTime)/(double)PeriodSeconds(divTF));
            if(barsBetweenH<=maxDivBars && curPriceH>st.prevPHPrice && phRsi<st.prevPHRsi)
            { bearDiv=true; pivotBearPx=curPriceH; }
         }
         st.prevPHPrice=curPriceH; st.prevPHRsi=phRsi; st.prevPHTime=curTimeH; st.havePH=true;
      }

      if(!st.armed && !st.inTrade && canTradeMore)
      {
         if(bullDiv)
         {
            st.dirState=1; st.anchorPx=pivotBullPx; st.anchorValid=true; divJustDetected=true;
            if(useZonePullback) { st.armed=true; st.waitingEntry=true; st.barsWaited=0; }
            else
            {
               st.entryPx = iClose(symbol,divTF,1);
               if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1-slPct/100.0); st.tpPx=st.entryPx*(1+tpPct/100.0); }
               else { st.slPx=st.anchorPx; double riskPts=st.entryPx-st.slPx; st.tpPx=st.entryPx+riskPts*rr; }
               st.inTrade=true; st.tradeDir=1; st.beDone=false; justEntered=true;
            }
         }
         else if(bearDiv)
         {
            st.dirState=-1; st.anchorPx=pivotBearPx; st.anchorValid=true; divJustDetected=true;
            if(useZonePullback) { st.armed=true; st.waitingEntry=true; st.barsWaited=0; }
            else
            {
               st.entryPx = iClose(symbol,divTF,1);
               if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1+slPct/100.0); st.tpPx=st.entryPx*(1-tpPct/100.0); }
               else { st.slPx=st.anchorPx; double riskPts=st.slPx-st.entryPx; st.tpPx=st.entryPx-riskPts*rr; }
               st.inTrade=true; st.tradeDir=-1; st.beDone=false; justEntered=true;
            }
         }
      }
   }

   if(st.waitingEntry && newEntryBar)
   {
      st.barsWaited++;
      if(st.barsWaited > maxWaitBars) { st.armed=false; st.waitingEntry=false; }
   }

   if(newEntryBar) ShiftEntryHistory(st, symbol, entryTF);

   bool zoneJustSet=false;
   if(useZonePullback && newEntryBar && st.armed && st.waitingEntry && !st.inTrade)
   {
      double zTop=0, zBot=0;
      if(DetectZone(st, useOB, useFVG, zTop, zBot))
      { st.zoneTop=zTop; st.zoneBot=zBot; st.zoneValid=true; zoneJustSet=true; zoneJustFound=true; }
   }

   if(useZonePullback && newEntryBar && !zoneJustSet && st.armed && st.waitingEntry && !st.inTrade && st.zoneValid && canTradeMore && sessionOk)
   {
      if(st.dirState==1 && st.e3L<=st.zoneTop && st.e3C>st.zoneBot && st.e3C>st.e3O)
      {
         st.inTrade=true; st.tradeDir=1; st.entryPx=st.e3C;
         if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1-slPct/100.0); st.tpPx=st.entryPx*(1+tpPct/100.0); }
         else { st.slPx=MathMin(st.zoneBot, st.anchorPx); double riskPts=st.entryPx-st.slPx; st.tpPx=st.entryPx+riskPts*rr; }
         st.beDone=false; st.waitingEntry=false; justEntered=true;
      }
      else if(st.dirState==-1 && st.e3H>=st.zoneBot && st.e3C<st.zoneTop && st.e3C<st.e3O)
      {
         st.inTrade=true; st.tradeDir=-1; st.entryPx=st.e3C;
         if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1+slPct/100.0); st.tpPx=st.entryPx*(1-tpPct/100.0); }
         else { st.slPx=MathMax(st.zoneTop, st.anchorPx); double riskPts=st.slPx-st.entryPx; st.tpPx=st.entryPx-riskPts*rr; }
         st.beDone=false; st.waitingEntry=false; justEntered=true;
      }
   }

   if(selfManageExit)
      ManageSimulatedExit(st, symbol, entryTF, enableBE, beTriggerR, oneSignalPerDiv, beTriggered);
}

//====================================================================
// STRATEGY 4 ENGINE -- BOLLINGER BANDS
//====================================================================
void UpdateBBPair(PairState &st, string symbol,
   bool pairOn, ENUM_TIMEFRAMES bbTF, ENUM_TF_MODE tfMode, ENUM_TIMEFRAMES entryTFin,
   int bbLen, double bbMult, ENUM_BB_SIGNAL_MODE bbMode,
   ENUM_BB_ENTRY_MODE entryMode, bool useOB, bool useFVG, int maxWaitBars, bool oneSignalPerBB,
   double rr, bool canTradeMore, bool sessionOk,
   ENUM_SLTP_METHOD slTpMethod, double slPct, double tpPct,
   bool enableBE, double beTriggerR, bool selfManageExit,
   bool &justEntered, bool &bbJustDetected, bool &zoneJustFound, bool &htfBarSeen, bool &beTriggered)
{
   justEntered=false; bbJustDetected=false; zoneJustFound=false; htfBarSeen=false; beTriggered=false;
   if(!pairOn) return;

   ENUM_TIMEFRAMES entryTF = (tfMode==TFMODE_PAIR) ? entryTFin : bbTF;
   bool useZonePullback = (entryMode==BBMODE_ZONE);
   bool isBreakout = (bbMode==BB_BREAKOUT);

   datetime t0B = iTime(symbol, bbTF, 0);
   datetime t0E = iTime(symbol, entryTF, 0);
   bool newBBBar    = st.htfValid && (t0B != st.htfTime);
   bool newEntryBar = st.entryValid && (t0E != st.entryTime);
   st.htfTime=t0B; st.htfValid=true;
   st.entryTime=t0E; st.entryValid=true;

   if(newBBBar)
   {
      htfBarSeen=true;
      if(!st.armed && !st.inTrade && canTradeMore)
      {
         double closedDH=iHigh(symbol,bbTF,1), closedDL=iLow(symbol,bbTF,1), closedDC=iClose(symbol,bbTF,1);
         double basis = iBands(symbol,bbTF,bbLen,bbMult,0,PRICE_CLOSE,MODE_MAIN,1);
         double upper = iBands(symbol,bbTF,bbLen,bbMult,0,PRICE_CLOSE,MODE_UPPER,1);
         double lower = iBands(symbol,bbTF,bbLen,bbMult,0,PRICE_CLOSE,MODE_LOWER,1);

         bool bullSig = isBreakout ? (closedDC>upper) : (closedDL<lower && closedDC>lower);
         bool bearSig = isBreakout ? (closedDC<lower) : (closedDH>upper && closedDC<upper);
         double anchorBull = isBreakout ? basis : closedDL;
         double anchorBear = isBreakout ? basis : closedDH;

         if(bullSig)
         {
            st.dirState=1; st.anchorPx=anchorBull; st.anchorValid=true; bbJustDetected=true;
            if(useZonePullback) { st.armed=true; st.waitingEntry=true; st.barsWaited=0; }
            else
            {
               st.entryPx=closedDC;
               if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1-slPct/100.0); st.tpPx=st.entryPx*(1+tpPct/100.0); }
               else { st.slPx=st.anchorPx; double riskPts=st.entryPx-st.slPx; st.tpPx=st.entryPx+riskPts*rr; }
               st.inTrade=true; st.tradeDir=1; st.beDone=false; justEntered=true;
            }
         }
         else if(bearSig)
         {
            st.dirState=-1; st.anchorPx=anchorBear; st.anchorValid=true; bbJustDetected=true;
            if(useZonePullback) { st.armed=true; st.waitingEntry=true; st.barsWaited=0; }
            else
            {
               st.entryPx=closedDC;
               if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1+slPct/100.0); st.tpPx=st.entryPx*(1-tpPct/100.0); }
               else { st.slPx=st.anchorPx; double riskPts=st.slPx-st.entryPx; st.tpPx=st.entryPx-riskPts*rr; }
               st.inTrade=true; st.tradeDir=-1; st.beDone=false; justEntered=true;
            }
         }
      }
   }

   if(st.waitingEntry && newEntryBar)
   {
      st.barsWaited++;
      if(st.barsWaited > maxWaitBars) { st.armed=false; st.waitingEntry=false; }
   }

   if(newEntryBar) ShiftEntryHistory(st, symbol, entryTF);

   bool zoneJustSet=false;
   if(useZonePullback && newEntryBar && st.armed && st.waitingEntry && !st.inTrade)
   {
      double zTop=0, zBot=0;
      if(DetectZone(st, useOB, useFVG, zTop, zBot))
      { st.zoneTop=zTop; st.zoneBot=zBot; st.zoneValid=true; zoneJustSet=true; zoneJustFound=true; }
   }

   if(useZonePullback && newEntryBar && !zoneJustSet && st.armed && st.waitingEntry && !st.inTrade && st.zoneValid && canTradeMore && sessionOk)
   {
      if(st.dirState==1 && st.e3L<=st.zoneTop && st.e3C>st.zoneBot && st.e3C>st.e3O)
      {
         st.inTrade=true; st.tradeDir=1; st.entryPx=st.e3C;
         if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1-slPct/100.0); st.tpPx=st.entryPx*(1+tpPct/100.0); }
         else { st.slPx=MathMin(st.zoneBot, st.anchorPx); double riskPts=st.entryPx-st.slPx; st.tpPx=st.entryPx+riskPts*rr; }
         st.beDone=false; st.waitingEntry=false; justEntered=true;
      }
      else if(st.dirState==-1 && st.e3H>=st.zoneBot && st.e3C<st.zoneTop && st.e3C<st.e3O)
      {
         st.inTrade=true; st.tradeDir=-1; st.entryPx=st.e3C;
         if(slTpMethod==SLTP_FIXED_PERCENT) { st.slPx=st.entryPx*(1+slPct/100.0); st.tpPx=st.entryPx*(1-tpPct/100.0); }
         else { st.slPx=MathMax(st.zoneTop, st.anchorPx); double riskPts=st.slPx-st.entryPx; st.tpPx=st.entryPx-riskPts*rr; }
         st.beDone=false; st.waitingEntry=false; justEntered=true;
      }
   }

   if(selfManageExit)
      ManageSimulatedExit(st, symbol, entryTF, enableBE, beTriggerR, oneSignalPerBB, beTriggered);
}
//+------------------------------------------------------------------+
