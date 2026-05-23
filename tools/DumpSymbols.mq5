//+------------------------------------------------------------------+
//| DumpSymbols.mq5 - utility: print all broker symbols to the log.   |
//| Run headless in the Strategy Tester on any valid symbol; parse    |
//| the tester log for "SYM " lines. Exits immediately.               |
//+------------------------------------------------------------------+
#property version "1.00"

int OnInit()
{
   int total = SymbolsTotal(false);            // all broker symbols, not just Market Watch
   PrintFormat("DUMP_BEGIN total=%d", total);
   for(int i = 0; i < total; i++)
      Print("SYM ", SymbolName(i, false));
   PrintFormat("DUMP_END");
   ExpertRemove();
   return INIT_SUCCEEDED;
}
void OnTick() {}
