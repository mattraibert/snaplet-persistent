{-# LANGUAGE OverloadedStrings #-}

module Snap.Snaplet.Persistent where

-------------------------------------------------------------------------------
import           Control.Monad.State
import           Control.Monad.Trans.Resource
import           Data.ByteString (ByteString)
import           Data.Configurator
import           Data.Maybe
import           Data.Readable
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import           Database.Persist.Postgresql hiding (get)
import           Database.Persist.Store
import           Snap.Snaplet
import           Paths_snaplet_persistent
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
newtype PersistState = PersistState { persistPool :: ConnectionPool }


-------------------------------------------------------------------------------
initPersist :: Migration (SqlPersist IO) -> SnapletInit b PersistState
initPersist migration = makeSnaplet "persist" description datadir $ do
    p <- mkSnapletPgPool
    liftIO $ runSqlPool (runMigrationUnsafe migration) p
    return $ PersistState p
  where
    description = "Snaplet for persistent DB library"
    datadir = Just $ liftM (++"/resources/db") getDataDir


-------------------------------------------------------------------------------
mkSnapletPgPool :: (MonadIO (m b v), MonadSnaplet m) => m b v ConnectionPool
mkSnapletPgPool = do
  conf <- getSnapletUserConfig
  pgConStr <- liftIO $ require conf "postgre-con-str"
  cons <- liftIO $ require conf "postgre-pool-size"
  createPostgresqlPool pgConStr cons


-------------------------------------------------------------------------------
runPersist :: SqlPersist (ResourceT IO) a -> Handler b (PersistState) a
runPersist action = do
  pool <- gets persistPool
  liftIO . runResourceT $ runSqlPool action pool


-------------------------------------------------------------------------------
mkKey :: Int -> Key entity
mkKey = Key . toPersistValue


-------------------------------------------------------------------------------
mkKeyBS :: ByteString -> Key entity
mkKeyBS = mkKey . fromMaybe (error "Can't ByteString value") . fromBS


-------------------------------------------------------------------------------
mkKeyT :: Text -> Key entity
mkKeyT = mkKey . fromMaybe (error "Can't Text value") . fromText


-------------------------------------------------------------------------------
showKey :: Key e -> Text
showKey = T.pack . show . mkInt


-------------------------------------------------------------------------------
showKeyBS :: Key e -> ByteString
showKeyBS = T.encodeUtf8 . showKey


-------------------------------------------------------------------------------
mkInt :: Key a -> Int
mkInt = fromPersistValue' . unKey


-------------------------------------------------------------------------------
fromPersistValue' :: PersistField c => PersistValue -> c
fromPersistValue' = either (const $ error "Persist conversion failed") id
                    . fromPersistValue
