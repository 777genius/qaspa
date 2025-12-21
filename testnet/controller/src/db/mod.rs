pub mod entities;
mod writer;

pub use writer::MetricsWriter;

use sea_orm::{ConnectOptions, Database, DatabaseConnection};
use std::time::Duration;
use tracing::info;

pub async fn connect(database_url: &str) -> Result<DatabaseConnection, sea_orm::DbErr> {
    let mut opt = ConnectOptions::new(database_url);
    opt.max_connections(10)
        .min_connections(2)
        .connect_timeout(Duration::from_secs(10))
        .acquire_timeout(Duration::from_secs(10))
        .idle_timeout(Duration::from_secs(300))
        .max_lifetime(Duration::from_secs(600))
        .sqlx_logging(false);

    info!("Connecting to database...");
    let db = Database::connect(opt).await?;
    info!("Database connection established");

    Ok(db)
}

pub async fn run_migrations(db: &DatabaseConnection) -> Result<(), sea_orm_migration::DbErr> {
    use migration::MigratorTrait;
    info!("Running database migrations...");
    migration::Migrator::up(db, None).await?;
    info!("Database migrations completed");
    Ok(())
}
