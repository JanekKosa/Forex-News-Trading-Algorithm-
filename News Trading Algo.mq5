//+------------------------------------------------------------------+
//|                                            News Trading Algo.mq5 |
//+------------------------------------------------------------------+

#property tester_file "News_GBPUSD.txt"
#include<Trade\Trade.mqh>

//--USER DEFINED VARIABLES------------------------------------------------------
      //--Primary Timeframe--
input ENUM_TIMEFRAMES emaTimeframe = PERIOD_M15;
input ENUM_TIMEFRAMES lqTimeframe = PERIOD_M15;
      //--Trade Settings--
input double positionSize = 0.1; //Position Size     
input double profitTarget = 100; //Profit Target in Ticks
input double stoploss = 1000; //Stop Loss in Ticks
input double breakeven = 800; //Break even in Ticks
input int lesserEmaPeriod = 10; //Faster EMA period
input int greaterEmaPeriod = 30; //Slower EMA period
      //--File names--
input string NameOfFileWithNewsDates = "News_GBPUSD.txt";
//---IN CODE GLOBAL VARIABLES---------------------------------------------------
int lineIndex = -1;
datetime lastActionTime;
bool tradePlaced;
int fileHandle;
datetime newsCandleTime = NULL;
int secondsBeforeNews = 10;
datetime breakevenTime;
CTrade tradeInstance;
//---ENUMS--------------------------------------------------------------------
enum enumLqGrabType {
   bearish,
   bullish,
   null
};

enum enumTrendType {
   bear,
   bull
};

//---STRUCTS--------------------------------------------------------------------
struct EMAValues {
   double   greaterEMAValue;
   double   lesserEMAValue;
};

//------------------------------------------------------------------------------
int OnInit(){
   
   int pResult = openFile(NameOfFileWithNewsDates);
   
   return pResult;
}

//------------------------------------------------------------------------------
void OnTick(){

   performOperations();     
}
//-----------------------------------------------------------------------------
void performOperations(){

   if(iTime(Symbol(), PERIOD_M15, 0) != lastActionTime) {
      getNewsTime();
      tradePlaced = false;
      lastActionTime = iTime(Symbol(), PERIOD_M15, 0);
   }
   if(checkIfSecondsBeforeNews() == true){
      placeTradeOrder();
   }
   deleteOrder();
   //setTradeToBreakeven();
}
//------------------------------------------------------------------------------
int openFile(string aNewsFileName){
   
   fileHandle = FileOpen(aNewsFileName, FILE_READ|FILE_ANSI|FILE_COMMON);
   
   if (fileHandle == INVALID_HANDLE){
        Print("Failed to open file: ", aNewsFileName);
        return INIT_FAILED;
    }
    else{
      Print("File opened: ", aNewsFileName);
    }
    FileSeek(fileHandle, 0, SEEK_SET);
    
    return INIT_SUCCEEDED;
}
//------------------------------------------------------------------------------
bool getNewsTime(){
   
   datetime pNextCandleTime = iTime(Symbol(), PERIOD_M15, 0) + PeriodSeconds(PERIOD_M15);
   
   if(pNextCandleTime > newsCandleTime || newsCandleTime == NULL && FileIsEnding(fileHandle) == false){
      newsCandleTime = StringToTime(FileReadString(fileHandle));
   }
   
   if(newsCandleTime == pNextCandleTime){
      return true;
   }   
   return false;
}
//------------------------------------------------------------------------------
bool checkIfSecondsBeforeNews(){

   datetime pCurrentTime = TimeCurrent();
   datetime pTimeBeforeNews = newsCandleTime - secondsBeforeNews;
   
   if(pCurrentTime >= pTimeBeforeNews && pCurrentTime < newsCandleTime){
      return true;
   }
   return false;
}
//------------------------------------------------------------------------------
datetime stringToDateTime(string aTime) {

   string pDateString = TimeToString(TimeCurrent(), TIME_DATE);
   return StringToTime(pDateString + " " + aTime);
}
//------------------------------------------------------------------------------
EMAValues defineTrendFollowingEMAs(int aCandleIndex, int aLesserEmaPeriod, int aGreaterEmaPeriod) {

   EMAValues pEMAValues;

   double pGreaterEMAArray[];
   double pLesserEMAArray[];
   ArraySetAsSeries(pGreaterEMAArray, true);
   ArraySetAsSeries(pLesserEMAArray, true);
   CopyBuffer(iMA(Symbol(), emaTimeframe, aGreaterEmaPeriod, 0, MODE_EMA, PRICE_CLOSE), 0, 0, aCandleIndex + 1, pGreaterEMAArray);
   CopyBuffer(iMA(Symbol(), emaTimeframe, aLesserEmaPeriod, 0, MODE_EMA, PRICE_CLOSE), 0, 0, aCandleIndex + 1, pLesserEMAArray);
   pEMAValues.greaterEMAValue = pGreaterEMAArray[aCandleIndex];
   pEMAValues.lesserEMAValue = pLesserEMAArray[aCandleIndex];

   return pEMAValues;
}
//------------------------------------------------------------------------------
enumTrendType defineTrend() {

   EMAValues pEMAValues;
   pEMAValues = defineTrendFollowingEMAs(1, lesserEmaPeriod, greaterEmaPeriod);

   double pGreaterEMA = pEMAValues.greaterEMAValue;
   double pLesserEMA = pEMAValues.lesserEMAValue;
   
   if(pLesserEMA > pGreaterEMA) {
      return bull;
   }
   if(pLesserEMA < pGreaterEMA) {
      return bear;
   }
   return -1;
}
//------------------------------------------------------------------------------
bool checkIfCandleIsHigh(int aCandleIndex){
   
   if(aCandleIndex > 2){
      int pSubtractCandles = 2;
      for(int i = aCandleIndex + 1; i <= aCandleIndex + 2; i++){
         if(iHigh(Symbol(), lqTimeframe, i) > iHigh(Symbol(), lqTimeframe, aCandleIndex)) return false;
         if(iHigh(Symbol(), lqTimeframe, i - pSubtractCandles) > iHigh(Symbol(), lqTimeframe, aCandleIndex)) return false;
         pSubtractCandles += 2;
      }
      return true;
   }
   return false;
}
//------------------------------------------------------------------------------
bool checkIfCandleIsLow(int aCandleIndex){
   
   if(aCandleIndex > 2){
      int pSubtractCandles = 2;
      for(int i = aCandleIndex + 1; i <= aCandleIndex + 2; i++){
         if(iLow(Symbol(), lqTimeframe, i) < iLow(Symbol(), lqTimeframe, aCandleIndex)) return false;
         if(iLow(Symbol(), lqTimeframe, i - pSubtractCandles) < iLow(Symbol(), lqTimeframe, aCandleIndex)) return false;
         pSubtractCandles += 2;
      }
      return true;
   }
   return false;
}
//------------------------------------------------------------------------------
datetime getHighBreakTime(int aHighIndex){
   
   for(int i = aHighIndex - 1; i >= 0; i--){
      if(iHigh(Symbol(), lqTimeframe, i) > iHigh(Symbol(), lqTimeframe, aHighIndex)) return iTime(Symbol(), lqTimeframe, i);
   }
   return NULL;
}
//------------------------------------------------------------------------------
datetime getLowBreakTime(int aLowIndex){
   
   for(int i = aLowIndex - 1; i >= 0; i--){
      if(iLow(Symbol(), lqTimeframe, i) < iLow(Symbol(), lqTimeframe, aLowIndex)) return iTime(Symbol(), lqTimeframe, i);
   }
   return NULL;
}
//------------------------------------------------------------------------------
enumLqGrabType getLatestLqGrabDirection(){
   
   struct lqGrab{
      datetime breakTime;
      enumLqGrabType type;
      datetime structureTime;
      double structurePrice;
   };
   lqGrab lqGrabs[];
   
   for(int i = 1; i <= 200; i++){
      if(checkIfCandleIsHigh(i) == true){
         if(getHighBreakTime(i) != NULL){
            ArrayResize(lqGrabs, ArraySize(lqGrabs) + 1, 0);
            lqGrabs[ArraySize(lqGrabs)-1].breakTime = getHighBreakTime(i);
            lqGrabs[ArraySize(lqGrabs)-1].type = bearish;
            lqGrabs[ArraySize(lqGrabs)-1].structureTime = iTime(Symbol(), lqTimeframe, i);
            lqGrabs[ArraySize(lqGrabs)-1].structurePrice = iHigh(Symbol(), lqTimeframe, i);
         }
      }
      if(checkIfCandleIsLow(i) == true){
         if(getLowBreakTime(i) != NULL){
            ArrayResize(lqGrabs, ArraySize(lqGrabs) + 1, 0);
            lqGrabs[ArraySize(lqGrabs)-1].breakTime = getLowBreakTime(i);
            lqGrabs[ArraySize(lqGrabs)-1].type = bullish;
            lqGrabs[ArraySize(lqGrabs)-1].structureTime = iTime(Symbol(), lqTimeframe, i);
            lqGrabs[ArraySize(lqGrabs)-1].structurePrice = iLow(Symbol(), lqTimeframe, i);
         }
      }
   }
   if(ArraySize(lqGrabs) > 0){
      datetime pLatestLqGrab = NULL;
      int pLatestLqGrabIndex;
      
      for(int i = 0; i < ArraySize(lqGrabs); i++){
         if(lqGrabs[i].breakTime > pLatestLqGrab){
            pLatestLqGrab = lqGrabs[i].breakTime;
            pLatestLqGrabIndex = i;
         }
      }
      drawLqGrab(lqGrabs[pLatestLqGrabIndex].structureTime, lqGrabs[pLatestLqGrabIndex].breakTime, lqGrabs[pLatestLqGrabIndex].structurePrice);  
      return lqGrabs[pLatestLqGrabIndex].type;
   }
   return null;
}
//------------------------------------------------------------------------------
void drawLqGrab(datetime aFirstAnchorTime, datetime aSecAnchorTime, double aPrice){

   lineIndex++;
   ObjectCreate(0, "line " + IntegerToString(lineIndex), OBJ_TREND, 0, aFirstAnchorTime, aPrice, aSecAnchorTime, aPrice);
}
//------------------------------------------------------------------------------
void placeTradeOrder(){

   if(getLatestLqGrabDirection() == bullish && defineTrend() == bull) placeBuyOrder();
   if(getLatestLqGrabDirection() == bearish && defineTrend() == bear) placeSellOrder();
}
//------------------------------------------------------------------------------
double getAtrValueTicks(){
   
   int pAtrHandle = iATR(Symbol(), PERIOD_D1, 5);
   double pAtrArray[];
   ArraySetAsSeries(pAtrArray, true);
   CopyBuffer(pAtrHandle, 0, 0, 5, pAtrArray);
   double pTickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   return pAtrArray[1]/pTickSize;
}
//------------------------------------------------------------------------------
double calculateTakeProfit(ENUM_POSITION_TYPE aPositionType){
   
   double pTickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   
   if(aPositionType == POSITION_TYPE_BUY){
      return SymbolInfoDouble(Symbol(), SYMBOL_BID) + (pTickSize * profitTarget);
   }
   else return SymbolInfoDouble(Symbol(), SYMBOL_BID) - (pTickSize * profitTarget);
}
//------------------------------------------------------------------------------
double calculateStopLoss(ENUM_POSITION_TYPE aPositionType){
   
   double pTickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   
   if(aPositionType == POSITION_TYPE_BUY){
      return SymbolInfoDouble(Symbol(), SYMBOL_BID) - (pTickSize * stoploss);
   }
   else return SymbolInfoDouble(Symbol(), SYMBOL_BID) + (pTickSize * stoploss);
}
//------------------------------------------------------------------------------
int tradeIndex = 0;

void placeBuyOrder(){
   
   double pCurrPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double pTickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   if(tradePlaced == false){
      tradeInstance.Buy(positionSize, Symbol(), NULL, calculateStopLoss(POSITION_TYPE_BUY), calculateTakeProfit(POSITION_TYPE_BUY), IntegerToString(tradeIndex));
      //tradeInstance.SellStop(positionSize/2,  pCurrPrice - (pTickSize * stoploss), Symbol(), pCurrPrice, pCurrPrice - (pTickSize * 2 * stoploss), NULL, NULL, IntegerToString(tradeIndex));
      tradeInstance.BuyLimit(positionSize/2, pCurrPrice - (pTickSize * stoploss), Symbol(), pCurrPrice - (pTickSize * 2 * stoploss), pCurrPrice - (pTickSize * stoploss) + (pTickSize * stoploss), NULL, NULL, IntegerToString(tradeIndex));
      tradeIndex++;
      tradePlaced = true;
   }
}
//------------------------------------------------------------------------------
void placeSellOrder(){
   
   double pCurrPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   double pTickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   if(tradePlaced == false){
      tradeInstance.Sell(positionSize, Symbol(), NULL, calculateStopLoss(POSITION_TYPE_SELL), calculateTakeProfit(POSITION_TYPE_SELL), IntegerToString(tradeIndex));
      //tradeInstance.BuyStop(positionSize/2, pCurrPrice + (pTickSize * stoploss), Symbol(), pCurrPrice, pCurrPrice + (pTickSize * 2 * stoploss), NULL, NULL, IntegerToString(tradeIndex));
      tradeInstance.SellLimit(positionSize/2, pCurrPrice + (pTickSize * stoploss), Symbol(), pCurrPrice + (pTickSize * 2 * stoploss), pCurrPrice + (pTickSize * stoploss) - (pTickSize * stoploss), NULL, NULL, IntegerToString(tradeIndex));
      tradeIndex++;
      tradePlaced = true;
   }
}
//------------------------------------------------------------------------------
void setTradeToBreakeven(){

   double pTickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   
   for(int i = PositionsTotal()-1; i>=0; i--) {
      PositionSelectByTicket(PositionGetTicket(i));
      
      if(PositionGetString(POSITION_SYMBOL) == Symbol()) {
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetDouble(POSITION_PRICE_CURRENT) >= PositionGetDouble(POSITION_PRICE_OPEN) + (pTickSize * breakeven)){
            tradeInstance.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP));
         }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetDouble(POSITION_PRICE_CURRENT) <= PositionGetDouble(POSITION_PRICE_OPEN) - (pTickSize * breakeven)){
            tradeInstance.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP));
         }
      }
   }
}
//------------------------------------------------------------------------------
void deleteOrder(){
   
   if(OrdersTotal() > 0){
      for(int j = OrdersTotal(); j >= 0; j--){
         OrderSelect(OrderGetTicket(j));
         if(OrderGetString(ORDER_SYMBOL) == Symbol()){
            string pComment = OrderGetString(ORDER_COMMENT);
            bool pOpenTradeFound = false;
            for(int i = PositionsTotal(); i >= 0; i--){
               PositionSelectByTicket(PositionGetTicket(i));
               if(PositionGetString(POSITION_COMMENT) == pComment){
                  pOpenTradeFound = true;
               }
            }
            if(pOpenTradeFound == false) tradeInstance.OrderDelete(OrderGetTicket(j));
         }
      }
   }
}
//------------------------------------------------------------------------------
bool isRestrictedTime(){
         
   MqlDateTime pDateTimeStruct;
   TimeToStruct(TimeCurrent(), pDateTimeStruct);
   datetime pSessionStart, pSessionEnd;
   SymbolInfoSessionTrade(Symbol(), (ENUM_DAY_OF_WEEK)pDateTimeStruct.day_of_week, 0, pSessionStart, pSessionEnd);
   string pSessionStartTime = TimeToString(pSessionStart, TIME_MINUTES);
   string pSessionEndTime = TimeToString(pSessionEnd, TIME_MINUTES);
   if(TimeCurrent() > stringToDateTime(pSessionStartTime) && TimeCurrent() < stringToDateTime(pSessionEndTime)){
      return false;
   }
   return true;
}
