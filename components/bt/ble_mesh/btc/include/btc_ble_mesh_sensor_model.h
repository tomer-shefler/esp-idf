// Copyright 2017-2018 Espressif Systems (Shanghai) PTE LTD
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef _BTC_BLE_MESH_SENSOR_MODEL_H_
#define _BTC_BLE_MESH_SENSOR_MODEL_H_

#include <stdint.h>
#include "btc/btc_task.h"
#include "esp_ble_mesh_sensor_model_api.h"

typedef enum {
    BTC_BLE_MESH_ACT_SENSOR_CLIENT_GET_STATE,
    BTC_BLE_MESH_ACT_SENSOR_CLIENT_SET_STATE,
} btc_ble_mesh_sensor_client_act_t;

typedef union {
    struct ble_mesh_sensor_client_get_state_reg_args {
        esp_ble_mesh_client_common_param_t *params;
        esp_ble_mesh_sensor_client_get_state_t *get_state;
    } sensor_client_get_state;
    struct ble_mesh_sensor_client_set_state_reg_args {
        esp_ble_mesh_client_common_param_t *params;
        esp_ble_mesh_sensor_client_set_state_t *set_state;
    } sensor_client_set_state;
} btc_ble_mesh_sensor_client_args_t;

void btc_mesh_sensor_client_call_handler(btc_msg_t *msg);

void btc_mesh_sensor_client_cb_handler(btc_msg_t *msg);

void btc_ble_mesh_sensor_client_arg_deep_copy(btc_msg_t *msg, void *p_dest, void *p_src);

void btc_mesh_sensor_client_publish_callback(u32_t opcode, struct bt_mesh_model *model,
        struct bt_mesh_msg_ctx *ctx, struct net_buf_simple *buf);

void bt_mesh_callback_sensor_status_to_btc(u32_t opcode, u8_t evt_type,
        struct bt_mesh_model *model,
        struct bt_mesh_msg_ctx *ctx,
        const u8_t *val, size_t len);

#endif /* _BTC_BLE_MESH_SENSOR_MODEL_H_ */

