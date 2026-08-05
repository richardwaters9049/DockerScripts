use axum::{
    routing::get,
    Router,
};

use std::net::SocketAddr;

use tracing_subscriber;


async fn health_check() -> &'static str {

    "Backend is running"

}


#[tokio::main]
async fn main() {

    tracing_subscriber::fmt::init();


    let app = Router::new()
        .route("/health", get(health_check));


    let address = SocketAddr::from(([0, 0, 0, 0], 8000));


    println!("Backend running on {}", address);


    let listener = tokio::net::TcpListener::bind(address)
        .await
        .unwrap();


    axum::serve(listener, app)
        .await
        .unwrap();

}