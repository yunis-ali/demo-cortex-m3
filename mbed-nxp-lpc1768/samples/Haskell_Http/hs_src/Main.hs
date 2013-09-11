import Control.Monad
import System.IO.Unsafe

import Delay
import Gpio
import qualified TextLCD as LCD
import EthernetInterface
import TCPSocketConnection
import ParseRss

receiveAll tcp = unsafeInterleaveIO receiveAll' where
  receiveAll' = do
    s <- tcpSocketConnection_receive tcp
    if s == "" then return [] else do
      s' <- unsafeInterleaveIO receiveAll'
      return $ s ++ s'

slowPutstr lcd str = do
  let col = LCD.columns lcd
  slowPutstr' lcd str

slowPutstr' lcd []         = return ()
slowPutstr' lcd str@(x:xs) = do
  let col = LCD.columns lcd
  delayMs 10
  LCD.locate lcd 0 1
  LCD.putstr lcd $ take col str
  slowPutstr lcd xs

printRss lcd host (headline, url) = do
  tcp <- tcpSocketConnection_connect host 80
  tcpSocketConnection_send_all tcp $ "GET " ++ url ++ " HTTP/1.0\n\n"
  r <- receiveAll tcp
  LCD.cls lcd
  LCD.putstr lcd $ ">>" ++ headline
  printTitle (slowPutstr lcd) r
  tcpSocketConnection_close tcp
  delayMs 1000
  return ()

main :: IO ()
main = do
  let p24 = pinName 2 2
      p26 = pinName 2 0
      p27 = pinName 0 11
      p28 = pinName 0 10
      p29 = pinName 0 5
      p30 = pinName 0 4
  lcd <- LCD.initTextLCD p24 p26 (p27, p28, p29, p30) LCD.LCD16x2
  -- DHCP
  LCD.putstr lcd "Start >>= "
  ethernetInitDhcp >>= LCD.putstr lcd . show
  ethernetConnect 12000 >>= LCD.putstr lcd . show
  LCD.putstr lcd "\nIP"
  ethernetGetIpAddress >>= LCD.putstr lcd
  delayMs 500
  -- TCP
  forever $ mapM_ (printRss lcd "www.reddit.com") [("Haskel", "http://www.reddit.com/r/haskell/.rss")
                                                  ,("OCaml", "http://www.reddit.com/r/ocaml/.rss")
                                                  ,("NetBSD", "http://www.reddit.com/r/NetBSD/.rss")
                                                  ,("Debian", "http://www.reddit.com/r/debian/.rss")
                                                  ,("Linux", "http://www.reddit.com/r/linux/.rss")
                                                  ]
