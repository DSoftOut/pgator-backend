// Written in D programming language
/**
*   This module defines high-level wrapper around libpq bindings.
*
*   The major goals:
*   <ul>
*       <li>Get more control over library errors (by converting to exceptions)</li>
*       <li>Create layer that can be mocked in purpose of unittesting</li>
*   </ul>
*
*   Copyright: © 2014 DSoftOut
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: NCrashed <ncrashed@gmail.com>
*/
module pgator.db.pq.api;

import dpq2.answer;
public import pgator.db.pq.types.oids;
import pgator.db.connection;
import pgator.db.pq.types.conv;
import vibe.data.bson;
import dlogg.log;

/**
*   Prototype: PGResult
*/
interface IPGresult
{
    synchronized:
    
    /**
    *   Prototype: PQresultStatus
    */
    ExecStatusType resultStatus() nothrow const;
    
    /**
    *   Prototype: PQresStatus
    *   Note: same as resultStatus, but converts 
    *         the enum to human-readable string.
    */
    string resStatus() const;
    
    /**
    *   Prototype: PQresultErrorMessage
    */
    string resultErrorMessage() const;
    
    /**
    *   Prototype: PQclear
    */
    //void clear() nothrow;
    
    /**
    *   Prototype: PQntuples
    */
    size_t ntuples() const nothrow;

    /**
    *   Prototype: PQnfields
    */
    size_t nfields() const nothrow;
        
    /**
    *   Prototype: PQfname
    */ 
    string fname(size_t colNumber) const;
    
    /**
    *   Prototype: PQfformat
    */
    bool isBinary(size_t colNumber) const;
    
    /**
    *   Prototype: PQgetvalue
    */
    string asString(size_t rowNumber, size_t colNumber) const;
    
    /**
    *   Prototype: PQgetvalue
    */
    ubyte[] asBytes(size_t rowNumber, size_t colNumber) const;
    
    /**
    *   Prototype: PQgetisnull
    */
    bool getisnull(size_t rowNumber, size_t colNumber) const;
    
    /**
    *   Prototype: PQftype
    */
    OidType ftype(size_t colNumber) const;
    
    /**
    *   Creates Bson from result in column echelon order.
    *   
    *   Bson consists of named arrays of column values.
    */
    Bson asColumnBson(shared IConnection conn) const;
    
    /// Getting local logger
    protected shared(ILogger) logger() nothrow;
}

/**
*   Prototype: PGconn
*/
interface IPGconn
{
    synchronized:
    
    /**
    *   Prototype: PQconnectPoll
    */
    PostgresPollingStatusType poll() nothrow;
    
    /**
    *   Prototype: PQstatus
    */
    ConnStatusType status() nothrow;
    
    /**
    *   Prototype: PQfinish
    *   Note: this function should be called even
    *   there was an error.
    */
    void finish() nothrow;
    
    /**
    *   Prototype: PQflush
    */
    bool flush() nothrow const;
    
    /**
    *   Prototype: PQresetStart
    *   Throws: PGReconnectException
    */
    void resetStart();
    
    /**
    *   Prototype: PQresetPoll
    */
    PostgresPollingStatusType resetPoll() nothrow;

    /**
    *   Prototype: PQerrorMessage
    */
    string errorMessage() const nothrow @property;
    
    /**
    *   Prototype: PQsendQueryParams
    *   Note: This is simplified version of the command that
    *         handles only string params.
    *   Warning: libpq doesn't support multiple SQL commands in
    *            the function. See the sendQueryParamsExt as
    *            an extended version of the function. 
    *   Throws: PGQueryException
    */
    void sendQueryParams(string command, string[] paramValues); 
    
    /**
    *   Prototype: PQsendQuery
    *   Throws: PGQueryException
    */
    void sendQuery(string command);
    
    /**
    *   Like sendQueryParams but uses libpq escaping functions
    *   and sendQuery. 
    *   
    *   The main advantage of the function is ability to handle
    *   multiple SQL commands in one query.
    *   Throws: PGQueryException
    */
    void sendQueryParamsExt(string command, string[] paramValues);
     
    /**
    *   Prototype: PQgetResult
    *   Note: Even when PQresultStatus indicates a fatal error, 
    *         PQgetResult should be called until it returns a null pointer 
    *         to allow libpq to process the error information completely.
    *   Note: A null pointer is returned when the command is complete and t
    *         here will be no more results.
    */
    shared(IPGresult) getResult();
    
    /**
    *   Prototype: PQconsumeInput
    *   Throws: PGQueryException
    */
    void consumeInput();
    
    /**
    *   Prototype: PQisBusy
    */
    bool isBusy() nothrow;
    
    /**
    *   Prototype: PQescapeLiteral
    *   Throws: PGEscapeException
    */
    string escapeLiteral(string msg);
    
    /**
    *   Prototype: PQparameterStatus
    *   Throws: PGParamNotExistException
    */
    string parameterStatus(string param);
    
    /**
    *   Prototype: PQsetNoticeProcessor
    */
    PQnoticeProcessor setNoticeProcessor(PQnoticeProcessor proc, void* arg) nothrow;
    
    /// Getting local logger
    protected shared(ILogger) logger() nothrow;

    string server() nothrow;
}

/**
*   OOP styled libpq wrapper to automatically handle library loading/unloading and
*   to provide mockable layer for unittests. 
*/
shared interface IPostgreSQL
{
    /**
    *   Prototype: PQconnectStart
    *   Throws: PGMemoryLackException
    */
    shared(IPGconn) startConnect(string conninfo);
}
