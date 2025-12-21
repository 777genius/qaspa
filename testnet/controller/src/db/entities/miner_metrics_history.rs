use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "miner_metrics_history")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i64,
    pub miner_id: String,
    pub hashrate: f64,
    pub blocks_found: i64,
    pub recorded_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}
