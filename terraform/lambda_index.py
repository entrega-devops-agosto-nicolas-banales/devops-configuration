import os
import json
import urllib.request
import urllib.error
import boto3
from datetime import datetime

def do_request(url, method="GET", data=None):
    req = urllib.request.Request(url, data=data, method=method)
    if data is not None:
        req.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(req) as response:
            response_body = response.read().decode('utf-8')
            return {"status_code": response.getcode(), "body": response_body}
    except urllib.error.HTTPError as e:
        return {"status_code": e.code, "body": f"HTTPError: {e.reason}"}
    except Exception as e:
        return {"status_code": None, "body": f"Error: {str(e)}"}

def handler(event, context):
    products_service_url = os.environ['PRODUCTS_SERVICE_URL']
    orders_service_url   = os.environ['ORDERS_SERVICE_URL']
    shipping_service_url = os.environ['SHIPPING_SERVICE_URL']
    s3_bucket = os.environ['S3_BUCKET']

    # Llamadas a los ms
    result_products = do_request(f"http://{products_service_url}/products", method="GET")

    result_product_111 = do_request(f"http://{products_service_url}/products/111", method="GET")

    order_body = json.dumps(["111"]).encode('utf-8')
    result_orders = do_request(f"http://{orders_service_url}/orders", method="POST", data=order_body)

    result_shipping = do_request(f"http://{shipping_service_url}/shipping/1234", method="POST")

    results = {
        "products_all": result_products,
        "products_111": result_product_111,
        "orders": result_orders,
        "shipping_1234": result_shipping,
        "timestamp": datetime.utcnow().isoformat()
    }

    # Guardar en S3
    s3 = boto3.client('s3')
    filename = f"monitor_results_{datetime.utcnow().isoformat()}.json"
    s3.put_object(
        Bucket=s3_bucket,
        Key=filename,
        Body=json.dumps(results).encode('utf-8')
    )

    return {"status": "success", "saved_file": filename, "data": results}
