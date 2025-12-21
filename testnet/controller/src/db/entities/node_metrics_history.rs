use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "node_metrics_history")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i64,
    pub node_id: String,
    pub block_count: i64,
    pub header_count: i64,
    pub virtual_daa_score: i64,
    pub peer_count: i32,
    pub mempool_size: i64,
    pub is_synced: bool,
    pub recorded_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}
