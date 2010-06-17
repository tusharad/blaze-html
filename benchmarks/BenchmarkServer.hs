-- | Benchmark server: all benchmarks from 'Utf8Html' can be requested through
-- this server via URL's.
--
-- Example:
--
-- > GET /manyAttributes HTTP/1.1
--
-- Will give you the @manyAttributes@ benchmark. URL's are case sensitive for
-- simplicity reasons.
--
{-# LANGUAGE OverloadedStrings #-}
module Main where

import Prelude hiding (putStrLn)

import Control.Concurrent (forkIO)
import Data.Monoid (mappend, mconcat)
import Control.Applicative ((<$>))
import Control.Monad (forever)
import Network.Socket (accept, sClose)
import Network (listenOn, PortID (PortNumber))
import System (getArgs)
import Data.Char (ord)
import Data.Map (Map)
import qualified Data.Map as M

import Network.Socket.ByteString (recv, send)
import Network.Socket.ByteString.Lazy (sendAll)
import qualified Data.ByteString as SB
import qualified Data.ByteString.Char8 as SBC
import qualified Data.ByteString.Lazy as LB

import Utf8Html (HtmlBenchmark (..), benchmarks)

main :: IO ()
main = do
    port <- PortNumber . fromIntegral . read . head <$> getArgs
    socket <- listenOn port
    forever $ do
        (s, _) <- accept socket
        forkIO (respond s)
  where
    respond s = do
        -- Get request from browser.
        input <- recv s 1024

        -- Parse URL.
        let requestUrl = (SB.split (fromIntegral $ ord ' ') input) !! 1
            requestedBenchmark = SBC.unpack $ SB.tail requestUrl
            benchmark = M.lookup requestedBenchmark benchmarkMap

        case benchmark of
            -- Benchmark found, run and return.
            Just (HtmlBenchmark _ f x) -> do
                _ <- send s $ "HTTP/1.1 200 OK\r\n"
                    `mappend` "Content-Type: text/html; charset=UTF-8\r\n"
                    `mappend` "\r\n"
                sendAll s $ f x

            -- No benchmark found, send a 404.
            Nothing -> do
                _ <- send s $ "HTTP/1.1 404 Not Found\r\n"
                    `mappend` "Content-Type: text/html; charset=UTF-8\r\n"
                    `mappend` "\r\n"
                    `mappend` "<h1>Page not found</h1>"
                return ()

        sClose s

    -- Construct a lookup table for benchmarks.
    benchmarkMap = let t b@(HtmlBenchmark n _ _) = (n, b)
                   in M.fromList $ map t benchmarks
