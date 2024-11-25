# File: approve_taiko_token.py
import os
from web3 import Web3
from eth_account import Account

# Load environment variables
L1_RPC_URL = os.environ.get('L1_RPC_URL', 'http://127.0.0.1:32002')
TAIKO_L1_ADDRESS = os.environ.get('TAIKO_L1_ADDRESS')
TAIKO_TOKEN_ADDRESS = os.environ.get('TAIKO_TOKEN_ADDRESS')
PRIVATE_KEY = os.environ.get('PRIVATE_KEY', 'c5114526e042343c6d1899cad05e1c00ba588314de9b96929914ee0df18d46b2')
SENDER_ADDRESS = os.environ.get('SENDER_ADDRESS', '0xD8F3183DEF51A987222D845be228e0Bbb932C222')

if not TAIKO_L1_ADDRESS or not TAIKO_TOKEN_ADDRESS:
    print("TAIKO_L1_ADDRESS or TAIKO_TOKEN_ADDRESS not set in environment variables.")
    exit(1)

# Connect to your Ethereum node
w3 = Web3(Web3.HTTPProvider(L1_RPC_URL))

# Check connection
if not w3.is_connected():
    print("Failed to connect to the Ethereum node.")
    exit()

# Sender's private key
private_key = PRIVATE_KEY

# Sender's and spender's addresses
sender_address = w3.to_checksum_address(SENDER_ADDRESS)
spender_address = w3.to_checksum_address(TAIKO_L1_ADDRESS)
value = 1000000000000000000000000000  # Amount to approve

# Ensure the private key corresponds to the sender address
account = w3.eth.account.from_key(private_key)
assert sender_address.lower() == account.address.lower(), "Private key does not match sender address"

# ABI for the approve function
abi = [{
    "constant": False,
    "inputs": [
        {"name": "spender", "type": "address"},
        {"name": "value", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
}]

# Contract address
contract_address = w3.to_checksum_address(TAIKO_TOKEN_ADDRESS)

# Create contract instance
contract = w3.eth.contract(address=contract_address, abi=abi)

# Get the nonce
nonce = w3.eth.get_transaction_count(sender_address)

# Build the transaction
chain_id = w3.eth.chain_id
transaction = contract.functions.approve(spender_address, value).build_transaction({
    'chainId': chain_id,
    'gas': 70000,
    'gasPrice': w3.to_wei('50', 'gwei'),
    'nonce': nonce
})

# Sign the transaction
signed_tx = w3.eth.account.sign_transaction(transaction, private_key)

# Send the transaction
tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
print(f"Transaction hash: {tx_hash.hex()}")

# Wait for the transaction receipt
print("Waiting for transaction receipt...")
receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
print(f"Transaction receipt status: {receipt.status}")
