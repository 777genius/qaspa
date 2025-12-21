use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // Create node_metrics_history table
        manager
            .create_table(
                Table::create()
                    .table(NodeMetricsHistory::Table)
                    .if_not_exists()
                    .col(ColumnDef::new(NodeMetricsHistory::Id).big_integer().not_null().auto_increment().primary_key())
                    .col(ColumnDef::new(NodeMetricsHistory::NodeId).string_len(64).not_null())
                    .col(ColumnDef::new(NodeMetricsHistory::BlockCount).big_integer().not_null())
                    .col(ColumnDef::new(NodeMetricsHistory::HeaderCount).big_integer().not_null())
                    .col(ColumnDef::new(NodeMetricsHistory::VirtualDaaScore).big_integer().not_null())
                    .col(ColumnDef::new(NodeMetricsHistory::PeerCount).integer().not_null())
                    .col(ColumnDef::new(NodeMetricsHistory::MempoolSize).big_integer().not_null())
                    .col(ColumnDef::new(NodeMetricsHistory::IsSynced).boolean().not_null())
                    .col(
                        ColumnDef::new(NodeMetricsHistory::RecordedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        // Create index for node_metrics_history
        manager
            .create_index(
                Index::create()
                    .name("idx_node_metrics_node_time")
                    .table(NodeMetricsHistory::Table)
                    .col(NodeMetricsHistory::NodeId)
                    .col((NodeMetricsHistory::RecordedAt, IndexOrder::Desc))
                    .to_owned(),
            )
            .await?;

        // Create miner_metrics_history table
        manager
            .create_table(
                Table::create()
                    .table(MinerMetricsHistory::Table)
                    .if_not_exists()
                    .col(ColumnDef::new(MinerMetricsHistory::Id).big_integer().not_null().auto_increment().primary_key())
                    .col(ColumnDef::new(MinerMetricsHistory::MinerId).string_len(64).not_null())
                    .col(ColumnDef::new(MinerMetricsHistory::Hashrate).double().not_null())
                    .col(ColumnDef::new(MinerMetricsHistory::BlocksFound).big_integer().not_null())
                    .col(
                        ColumnDef::new(MinerMetricsHistory::RecordedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        // Create index for miner_metrics_history
        manager
            .create_index(
                Index::create()
                    .name("idx_miner_metrics_miner_time")
                    .table(MinerMetricsHistory::Table)
                    .col(MinerMetricsHistory::MinerId)
                    .col((MinerMetricsHistory::RecordedAt, IndexOrder::Desc))
                    .to_owned(),
            )
            .await?;

        // Create aggregate_metrics_history table
        manager
            .create_table(
                Table::create()
                    .table(AggregateMetricsHistory::Table)
                    .if_not_exists()
                    .col(ColumnDef::new(AggregateMetricsHistory::Id).big_integer().not_null().auto_increment().primary_key())
                    .col(ColumnDef::new(AggregateMetricsHistory::TotalNodes).integer().not_null())
                    .col(ColumnDef::new(AggregateMetricsHistory::RunningNodes).integer().not_null())
                    .col(ColumnDef::new(AggregateMetricsHistory::SyncedNodes).integer().not_null())
                    .col(ColumnDef::new(AggregateMetricsHistory::TotalMiners).integer().not_null())
                    .col(ColumnDef::new(AggregateMetricsHistory::RunningMiners).integer().not_null())
                    .col(ColumnDef::new(AggregateMetricsHistory::TotalBlockCount).big_integer().not_null())
                    .col(ColumnDef::new(AggregateMetricsHistory::VirtualDaaScore).big_integer().not_null())
                    .col(ColumnDef::new(AggregateMetricsHistory::TotalHashrate).double().not_null())
                    .col(
                        ColumnDef::new(AggregateMetricsHistory::RecordedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        // Create index for aggregate_metrics_history
        manager
            .create_index(
                Index::create()
                    .name("idx_aggregate_metrics_time")
                    .table(AggregateMetricsHistory::Table)
                    .col((AggregateMetricsHistory::RecordedAt, IndexOrder::Desc))
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(AggregateMetricsHistory::Table).to_owned()).await?;
        manager.drop_table(Table::drop().table(MinerMetricsHistory::Table).to_owned()).await?;
        manager.drop_table(Table::drop().table(NodeMetricsHistory::Table).to_owned()).await?;
        Ok(())
    }
}

#[derive(Iden)]
enum NodeMetricsHistory {
    Table,
    Id,
    NodeId,
    BlockCount,
    HeaderCount,
    VirtualDaaScore,
    PeerCount,
    MempoolSize,
    IsSynced,
    RecordedAt,
}

#[derive(Iden)]
enum MinerMetricsHistory {
    Table,
    Id,
    MinerId,
    Hashrate,
    BlocksFound,
    RecordedAt,
}

#[derive(Iden)]
enum AggregateMetricsHistory {
    Table,
    Id,
    TotalNodes,
    RunningNodes,
    SyncedNodes,
    TotalMiners,
    RunningMiners,
    TotalBlockCount,
    VirtualDaaScore,
    TotalHashrate,
    RecordedAt,
}
