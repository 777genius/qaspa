use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "aggregate_metrics_history")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i64,
    pub total_nodes: i32,
    pub running_nodes: i32,
    pub synced_nodes: i32,
    pub total_miners: i32,
    pub running_miners: i32,
    pub total_block_count: i64,
    pub virtual_daa_score: i64,
    pub total_hashrate: f64,
    pub recorded_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}
