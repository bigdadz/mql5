//+------------------------------------------------------------------+
//|                                            PortfolioORB_EA.mq5    |
//|           Multi-symbol Opening Range Breakout portfolio EA       |
//+------------------------------------------------------------------+
#property copyright   "AIEA"
#property version     "1.00"
#property description "Multi-symbol ORB portfolio EA. Per-symbol OR window + state, account-level DD breaker, correlation guard."

#include <Trade/Trade.mqh>

#define MAX_SYMBOLS 16

enum ENUM_SIGNAL      { SIGNAL_NONE, SIGNAL_BUY, SIGNAL_SELL };
enum ENUM_BUFFER_MODE { BUFFER_POINTS, BUFFER_ATR };
enum ENUM_SL_MODE     { SL_RANGE_OPPOSITE, SL_ATR };
enum ENUM_DD_ACTION   { DD_STOP_ONLY, DD_CLOSE_ALL };
enum ENUM_ENTRY_STATE { ENTRY_IDLE, ENTRY_ARMED, ENTRY_DONE };

input group "General"
input long            InpMagic            = 20260521;
input int             InpDeviation        = 20;
input ENUM_TIMEFRAMES InpTimeframe        = PERIOD_M5;
input bool            InpDebugMode        = false;

input group "Portfolio (per-symbol, comma-separated, same order)"
input string InpSymbols        = "GBPUSDm,EURUSDm,USDJPYm,XAUUSDm";
input string InpORStartHours   = "6,7,8,9";       // per symbol
input string InpORWindowMins   = "30,30,15,60";   // per symbol (OR length)
input string InpMaxSpreadPts   = "40,40,40,600";  // per symbol

input group "Session (shared) — trade window measured from each symbol's OR end"
input int  InpTradeWindowMins  = 210;   // entries allowed for N min after OR end (210 = GBP 06:30->10:00)
input bool InpForceCloseEnable = true;
input int  InpForceCloseHour   = 20;
input int  InpForceCloseMin    = 0;

input group "Range / Signal"
input ENUM_BUFFER_MODE InpBufferMode     = BUFFER_ATR;
input int              InpBufferPoints   = 50;
input double           InpBufferATRmult  = 0.10;
input bool             InpRequireBarClose= true;
input int              InpATRPeriod      = 14;

input group "Risk"
input double         InpRiskPercent           = 1.0;     // per trade, per symbol
input double         InpMaxPortfolioDDPercent = 10.0;    // account-level daily DD breaker
input ENUM_DD_ACTION InpDDAction              = DD_STOP_ONLY;

input group "Exit / Trailing"
input ENUM_SL_MODE InpSLMode          = SL_RANGE_OPPOSITE;
input int          InpSLBufferPoints  = 30;
input double       InpSLATRmult       = 1.5;
input double       InpTP_R            = 1.8;
input double       InpBE_TriggerR     = 1.0;
input double       InpTrailStartR     = 1.2;
input int          InpTrailDistPoints = 200;

input group "Filters"
input bool            InpUseRangeFilter        = true;
input double          InpMinRangeATR           = 0.5;
input double          InpMaxRangeATR           = 3.0;
input bool            InpUseTrendFilter        = true;
input ENUM_TIMEFRAMES InpTrendTF               = PERIOD_H1;
input int             InpTrendEMA              = 50;
input bool            InpUseNewsFilter         = true;
input int             InpNewsMinsBefore        = 30;
input int             InpNewsMinsAfter         = 30;
input string          InpNewsCurrencies        = "GBP,USD,EUR,JPY";
input bool            InpUseRetest             = true;
input int             InpRetestTolerancePoints = 50;
input int             InpRetestTimeoutBars     = 6;

input group "Correlation guard"
input bool   InpUseCorrGuard = true;
input string InpCorrGroups   = "GBPUSDm,EURUSDm";  // ; separates groups, , separates members

input group "Display"
input bool InpShowDashboard = true;

CTrade trade;

int    g_lastDay        = -1;     // account-level new-day reset
double g_dayStartEquity = 0.0;    // account equity at day start (portfolio DD base)
bool   g_ddStopped      = false;  // portfolio DD latch (per day)
bool   g_newsWarned     = false;

// Parsed per-symbol config (index-aligned)
string g_symbol[];          // symbol names
int    g_orStartH[];        // OR start hour
int    g_orStartM[];        // OR start min (always 0 here)
int    g_orEndH[];          // OR end hour   (derived)
int    g_orEndM[];          // OR end min    (derived)
int    g_maxSpread[];       // per-symbol max spread (points)
int    g_symCount = 0;

// Split "a,b,c" into parts[]; returns count.
int SplitCSV(const string s, string &parts[])
{
   return StringSplit(s, ',', parts);
}

void OnTick()  { }
void OnTimer() { }
